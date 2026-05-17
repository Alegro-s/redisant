
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use serde::Deserialize;
use serde_json::json;
use serde_json::Value as JsonValue;
use chrono::{Utc, SecondsFormat};
use std::time::Duration;
use uuid::Uuid;

use crate::{get_user_id_from_token, AppState, ErrorResponse};

#[derive(Deserialize)]
pub struct HeartbeatBody {
    #[serde(default)]
    pub schema: Option<serde_json::Value>,
    #[serde(default)]
    pub metrics: Option<serde_json::Value>,
}

fn jwt_secret() -> Result<String, HttpResponse> {
    std::env::var("JWT_SECRET").map_err(|_| {
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        })
    })
}

pub async fn agent_heartbeat(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<HeartbeatBody>,
) -> impl Responder {
    let key = req
        .headers()
        .get("X-Agent-Key")
        .and_then(|h| h.to_str().ok())
        .map(str::trim)
        .filter(|s| !s.is_empty());
    let Some(agent_key) = key else {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Missing X-Agent-Key".into(),
        });
    };

    let parse_as_f64 = |obj: &JsonValue, keys: &[&str]| -> Option<f64> {
        for k in keys {
            if let Some(v) = obj.get(*k) {
                if let Some(f) = v.as_f64() {
                    return Some(f);
                }
                if let Some(i) = v.as_i64() {
                    return Some(i as f64);
                }
            }
        }
        None
    };

    let parse_as_usize = |obj: &JsonValue, keys: &[&str]| -> Option<usize> {
        for k in keys {
            if let Some(v) = obj.get(*k) {
                if let Some(u) = v.as_u64() {
                    return Some(u as usize);
                }
                if let Some(i) = v.as_i64() {
                    if i >= 0 {
                        return Some(i as usize);
                    }
                }
            }
        }
        None
    };

    let row: Option<(Uuid,)> = sqlx::query_as(
        "SELECT user_id FROM user_workspace WHERE agent_api_key = $1",
    )
    .bind(agent_key)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    let Some((user_id,)) = row else {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Invalid agent key".into(),
        });
    };

    let schema = body.schema.clone().unwrap_or(json!({}));
    let metrics = body.metrics.clone();

    if let Err(e) = sqlx::query(
        r#"UPDATE user_workspace SET
             agent_schema_snapshot = $1,
             agent_last_seen = now(),
             updated_at = now()
           WHERE user_id = $2"#,
    )
    .bind(&schema)
    .bind(user_id)
    .execute(&state.pool)
    .await
    {
        log::error!("agent_heartbeat: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to save schema".into(),
        });
    }

    if let Some(m) = metrics {
        if m.is_object() {
            let time = m
                .get("time")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string())
                .or_else(|| {
                    m.get("timestamp")
                        .and_then(|v| v.as_str())
                        .map(|s| s.to_string())
                })
                .unwrap_or_else(|| Utc::now().to_rfc3339_opts(SecondsFormat::Secs, true));

            let cpu = parse_as_f64(&m, &["cpu", "cpu_usage", "cpu_percent"]);
            let memory = parse_as_f64(&m, &["memory", "used_memory", "memory_used"]);
            let total_memory = parse_as_f64(&m, &["total_memory", "totalMemory", "total_mem"]);

            let disk_io = parse_as_f64(&m, &["disk_io", "diskIo", "disk_io_mb_s"]).unwrap_or(0.0);
            let network_rx = parse_as_f64(&m, &["network_rx", "net_rx", "rx"]).unwrap_or(0.0);
            let network_tx = parse_as_f64(&m, &["network_tx", "net_tx", "tx"]).unwrap_or(0.0);
            let requests = parse_as_usize(&m, &["requests", "rps"]).unwrap_or(0);

            if let (Some(cpu), Some(memory), Some(total_memory)) = (cpu, memory, total_memory) {
                let point = crate::MetricPoint {
                    time,
                    cpu,
                    memory,
                    total_memory,
                    disk_io,
                    network_rx,
                    network_tx,
                    requests,
                };
                let mut store = state.connected_metrics.lock().await;
                store.add_point_for_agent(&agent_key, point);
            }
        }
    }

    HttpResponse::Ok().json(json!({ "ok": true }))
}

pub async fn proxy_user_sql_to_agent(
    state: &web::Data<AppState>,
    req: &HttpRequest,
    query: &str,
) -> Result<Option<crate::DbQueryResponse>, HttpResponse> {
    let jwt_secret = jwt_secret()?;
    let user_id = get_user_id_from_token(req, &jwt_secret).ok_or_else(|| {
        HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        })
    })?;

    let row: Option<(Option<String>, Option<String>)> = sqlx::query_as(
        "SELECT connection_url, agent_api_key FROM user_workspace WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| {
        log::error!("proxy workspace: {}", e);
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Database error".into(),
        })
    })?;

    let Some((Some(base), Some(key))) = row else {
        return Ok(None);
    };
    let base = base.trim();
    if base.is_empty() {
        return Ok(None);
    }

    let url = format!("{}/v1/sql", base.trim_end_matches('/'));
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(120))
        .build()
        .map_err(|e| {
            log::error!("reqwest: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "HTTP client error".into(),
            })
        })?;

    let resp = client
        .post(&url)
        .header("X-Agent-Key", &key)
        .json(&json!({ "query": query }))
        .send()
        .await
        .map_err(|e| {
            log::error!("agent proxy: {}", e);
            HttpResponse::BadGateway().json(ErrorResponse {
                error: format!("Agent unreachable: {}", e),
            })
        })?;

    if !resp.status().is_success() {
        let txt = resp.text().await.unwrap_or_default();
        return Err(HttpResponse::BadGateway().json(ErrorResponse {
            error: format!("Agent error: {}", txt),
        }));
    }

    let v: serde_json::Value = resp.json().await.map_err(|e| {
        log::error!("agent json: {}", e);
        HttpResponse::BadGateway().json(ErrorResponse {
            error: "Invalid agent response".into(),
        })
    })?;

    let columns: Vec<String> = v
        .get("columns")
        .and_then(|c| c.as_array())
        .map(|a| a.iter().filter_map(|x| x.as_str().map(String::from)).collect())
        .unwrap_or_default();
    let rows: Vec<serde_json::Value> = v
        .get("rows")
        .and_then(|r| r.as_array())
        .cloned()
        .unwrap_or_default();

    Ok(Some(crate::DbQueryResponse { columns, rows }))
}

pub async fn get_agent_schema(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match jwt_secret() {
        Ok(s) => s,
        Err(e) => return e,
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let snap: Option<(Option<serde_json::Value>, Option<chrono::DateTime<chrono::Utc>>)> =
        sqlx::query_as(
            "SELECT agent_schema_snapshot, agent_last_seen FROM user_workspace WHERE user_id = $1",
        )
        .bind(user_id)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None);

    match snap {
        Some((Some(s), seen)) => HttpResponse::Ok().json(json!({
            "schema": s,
            "agent_last_seen": seen,
        })),
        Some((None, seen)) => HttpResponse::Ok().json(json!({
            "schema": null,
            "agent_last_seen": seen,
        })),
        None => HttpResponse::Ok().json(json!({
            "schema": null,
            "agent_last_seen": null,
        })),
    }
}
