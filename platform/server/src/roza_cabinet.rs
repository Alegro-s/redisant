//! Roza AI: дневные токены и квота, привязка к billing_accounts.plan.

use actix_web::{web, HttpRequest, HttpResponse, Responder};
use serde_json::json;
use uuid::Uuid;

use crate::waypoint_cabinet::billing_plan;
use crate::{get_user_id_from_token, AppState, ErrorResponse};

fn jwt_secret() -> Result<String, HttpResponse> {
    std::env::var("JWT_SECRET").map_err(|_| {
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        })
    })
}

async fn auth_uid(req: &HttpRequest) -> Result<Uuid, HttpResponse> {
    let secret = jwt_secret()?;
    get_user_id_from_token(req, &secret).ok_or_else(|| {
        HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        })
    })
}

pub fn roza_token_limit(plan: &str) -> i32 {
    match plan {
        "pro" | "team" | "enterprise" => std::env::var("ROZA_TOKEN_LIMIT_PRO")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(200_000),
        _ => std::env::var("ROZA_TOKEN_LIMIT_FREE")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(8_000),
    }
}

pub fn external_api_allowed(plan: &str) -> bool {
    matches!(plan, "pro" | "team" | "enterprise")
}

async fn tokens_used(pool: &sqlx::PgPool, user_id: Uuid) -> i32 {
    sqlx::query_scalar::<_, Option<i32>>(
        r#"SELECT tokens_used FROM roza_token_daily
           WHERE user_id = $1 AND usage_date = (timezone('utc', now()))::date"#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .ok()
    .flatten()
    .flatten()
    .unwrap_or(0)
}

/// Резервирует токены; возвращает Ok(used_after) или Err если лимит.
pub async fn consume_roza_tokens(
    pool: &sqlx::PgPool,
    user_id: Uuid,
    estimate: i32,
    limit: i32,
) -> Result<i32, sqlx::Error> {
    let row: Option<(i32,)> = sqlx::query_as(
        r#"
        INSERT INTO roza_token_daily (user_id, usage_date, tokens_used)
        VALUES ($1, (timezone('utc', now()))::date, $3)
        ON CONFLICT (user_id, usage_date)
        DO UPDATE SET
            tokens_used = roza_token_daily.tokens_used + $3,
            updated_at = now()
        WHERE roza_token_daily.tokens_used + $3 <= $2
        RETURNING tokens_used
        "#,
    )
    .bind(user_id)
    .bind(limit)
    .bind(estimate.max(1))
    .fetch_optional(pool)
    .await?;

    row.map(|(u,)| u).ok_or_else(|| sqlx::Error::RowNotFound)
}

pub async fn get_roza_quota(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let plan = billing_plan(&state.pool, uid).await;
    let limit = roza_token_limit(&plan);
    let used = tokens_used(&state.pool, uid).await;

    HttpResponse::Ok().json(json!({
        "plan": plan,
        "tokens_used": used,
        "tokens_limit": limit,
        "tokens_remaining": (limit - used).max(0),
        "external_api": external_api_allowed(&plan),
        "utc_date": chrono::Utc::now().date_naive().to_string(),
    }))
}

#[derive(serde::Deserialize)]
pub struct RozaConsumeBody {
    pub tokens: Option<i32>,
}

pub async fn post_roza_consume(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<RozaConsumeBody>,
) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let plan = billing_plan(&state.pool, uid).await;
    let limit = roza_token_limit(&plan);
    let estimate = body.tokens.unwrap_or(100).clamp(1, limit);

    match consume_roza_tokens(&state.pool, uid, estimate, limit).await {
        Ok(used) => HttpResponse::Ok().json(json!({
            "ok": true,
            "tokens_used": used,
            "tokens_limit": limit,
            "plan": plan,
        })),
        Err(_) => HttpResponse::TooManyRequests().json(json!({
            "ok": false,
            "error": "Дневной лимит токенов Roza AI исчерпан. Оформите подписку Pro в личном кабинете.",
            "tokens_used": tokens_used(&state.pool, uid).await,
            "tokens_limit": limit,
            "plan": plan,
        })),
    }
}
