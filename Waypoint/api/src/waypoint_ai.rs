
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::env;
use std::time::Duration;

use crate::{get_user_id_from_token, waypoint_cabinet, AppState, ErrorResponse};

fn jwt_secret() -> Result<String, HttpResponse> {
    env::var("JWT_SECRET").map_err(|_| {
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        })
    })
}

fn auth_uid(req: &HttpRequest) -> Result<uuid::Uuid, HttpResponse> {
    let secret = jwt_secret()?;
    get_user_id_from_token(req, &secret).ok_or_else(|| {
        HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        })
    })
}

#[derive(Deserialize, Serialize, Clone)]
pub struct ChatMessage {
    pub role: String,
    pub content: String,
}

#[derive(Deserialize)]
pub struct ChatRequest {
    pub messages: Vec<ChatMessage>,
    #[serde(default)]
    pub model: Option<String>,
    #[serde(default)]
    pub persona: Option<String>,
}

pub async fn deepseek_chat(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<ChatRequest>,
) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };

    if body.messages.is_empty() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "messages required".into(),
        });
    }

    let is_developer = body
        .persona
        .as_deref()
        .map(|p| p.eq_ignore_ascii_case("developer"))
        .unwrap_or(false);
    let persona_key = if is_developer { "developer" } else { "business" };

    let plan = waypoint_cabinet::billing_plan(&state.pool, uid).await;
    let daily_limit = waypoint_cabinet::ai_daily_limit(&plan, is_developer);

    let _reserved_count = match waypoint_cabinet::consume_ai_quota(&state.pool, uid, persona_key, daily_limit).await {
        Ok(Some(c)) => c,
        Ok(None) => {
            return HttpResponse::TooManyRequests().json(json!({
                "error": "ai_daily_quota_exceeded",
                "persona": persona_key,
                "limit": daily_limit,
                "plan": plan,
            }));
        }
        Err(e) => {
            log::error!("consume_ai_quota: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "quota database error".into(),
            });
        }
    };

    let key = match env::var("DEEPSEEK_API_KEY") {
        Ok(k) if !k.trim().is_empty() => k,
        _ => {
            return HttpResponse::ServiceUnavailable().json(ErrorResponse {
                error: "DEEPSEEK_API_KEY is not configured".into(),
            })
        }
    };

    let url = env::var("DEEPSEEK_API_URL").unwrap_or_else(|_| {
        "https://api.deepseek.com/v1/chat/completions".to_string()
    });

    let default_model = if is_developer {
        env::var("DEEPSEEK_MODEL_DEVELOPER")
            .ok()
            .filter(|s| !s.trim().is_empty())
            .unwrap_or_else(|| "deepseek-coder".to_string())
    } else {
        env::var("DEEPSEEK_MODEL_BUSINESS")
            .ok()
            .filter(|s| !s.trim().is_empty())
            .or_else(|| env::var("DEEPSEEK_MODEL").ok())
            .unwrap_or_else(|| "deepseek-chat".to_string())
    };

    let model = body
        .model
        .clone()
        .filter(|s| !s.trim().is_empty())
        .unwrap_or(default_model);

    let sys_business = env::var("DEEPSEEK_SYSTEM_BUSINESS").unwrap_or_else(|_| {
        "Ты помощник для бизнеса и операций в WaypointMetric: метрики, логистика, отчёты, документы. Отвечай по-русски, структурировано. Не выдумывай API; при нехватке данных задавай уточняющие вопросы.".to_string()
    });
    let sys_developer = env::var("DEEPSEEK_SYSTEM_DEVELOPER").unwrap_or_else(|_| {
        "Ты инженерный копилот: код, архитектура, алгоритмы, ревью. Отвечай по-русски, код в fenced blocks с языком. Указывай риски безопасности и граничные случаи.".to_string()
    });

    let mut messages = body.messages.clone();
    let has_system = messages.iter().any(|m| m.role.eq_ignore_ascii_case("system"));
    if !has_system {
        let content = if is_developer {
            sys_developer
        } else {
            sys_business
        };
        messages.insert(
            0,
            ChatMessage {
                role: "system".to_string(),
                content,
            },
        );
    }

    let payload = json!({
        "model": model,
        "messages": messages,
    });

    let client = match reqwest::Client::builder()
        .timeout(Duration::from_secs(120))
        .build()
    {
        Ok(c) => c,
        Err(e) => {
            log::error!("waypoint_ai client: {}", e);
            waypoint_cabinet::release_ai_quota(&state.pool, uid, persona_key).await;
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "http client error".into(),
            });
        }
    };

    let resp = client
        .post(&url)
        .header("Authorization", format!("Bearer {}", key))
        .header("Content-Type", "application/json")
        .json(&payload)
        .send()
        .await;

    match resp {
        Ok(r) => {
            let status = r.status();
            let text = r.text().await.unwrap_or_default();
            if !status.is_success() {
                log::warn!("deepseek non-success: {} {}", status, text.chars().take(200).collect::<String>());
                waypoint_cabinet::release_ai_quota(&state.pool, uid, persona_key).await;
                let code = actix_web::http::StatusCode::from_u16(status.as_u16())
                    .unwrap_or(actix_web::http::StatusCode::BAD_GATEWAY);
                return HttpResponse::build(code)
                    .content_type("application/json")
                    .body(text);
            }
            let v: Value = match serde_json::from_str(&text) {
                Ok(v) => v,
                Err(_) => {
                    return HttpResponse::Ok().content_type("application/json").body(text);
                }
            };
            HttpResponse::Ok().json(v)
        }
        Err(e) => {
            log::error!("deepseek request: {}", e);
            waypoint_cabinet::release_ai_quota(&state.pool, uid, persona_key).await;
            HttpResponse::BadGateway().json(ErrorResponse {
                error: format!("upstream: {}", e),
            })
        }
    }
}
