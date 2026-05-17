use actix_web::{web, HttpRequest, HttpResponse, Responder};
use chrono::{DateTime, Utc};
use serde::Serialize;
use serde_json::json;

use crate::{blocking, AppState, ErrorResponse};

#[derive(Serialize, sqlx::FromRow)]
struct LatestNamedMetric {
    name: String,
    value: f64,
    timestamp: DateTime<Utc>,
}

fn bad(msg: &str) -> HttpResponse {
    HttpResponse::Unauthorized().json(ErrorResponse {
        error: msg.into(),
    })
}

fn header_str<'a>(req: &'a HttpRequest, name: &str) -> Option<&'a str> {
    req.headers().get(name)?.to_str().ok()
}

fn normalized_features(raw: &serde_json::Value) -> Vec<&'static str> {
    let mut seen = std::collections::HashSet::new();
    let mut out = Vec::new();
    let Some(arr) = raw.as_array() else {
        return vec!["metrics_digest", "latest_metrics", "connection_ok"];
    };
    for v in arr {
        let Some(s) = v.as_str() else { continue };
        let key: Option<&'static str> = match s {
            "metrics_digest" | "Уведомления" => Some("metrics_digest"),
            "latest_metrics" | "Статистика" => Some("latest_metrics"),
            "alert_logs_digest" | "Callback API" => Some("alert_logs_digest"),
            "connection_ok" | "Рассылки" => Some("connection_ok"),
            "host_metrics_hint" => Some("host_metrics_hint"),
            _ => None,
        };
        if let Some(k) = key {
            if seen.insert(k) {
                out.push(k);
            }
        }
    }
    if out.is_empty() {
        return vec!["metrics_digest", "latest_metrics", "connection_ok"];
    }
    out
}

async fn metrics_digest_block(
    pool: &sqlx::PgPool,
    user_id: uuid::Uuid,
) -> Result<String, sqlx::Error> {
    let total: (i64,) = sqlx::query_as(
        r#"SELECT COUNT(*)::bigint
           FROM ingested_metrics m
           JOIN api_keys k ON m.api_key_id = k.id
           WHERE k.user_id = $1"#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await?;

    let distinct: (i64,) = sqlx::query_as(
        r#"SELECT COUNT(DISTINCT m.name)::bigint
           FROM ingested_metrics m
           JOIN api_keys k ON m.api_key_id = k.id
           WHERE k.user_id = $1"#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await?;

    let last24: (i64,) = sqlx::query_as(
        r#"SELECT COUNT(*)::bigint
           FROM ingested_metrics m
           JOIN api_keys k ON m.api_key_id = k.id
           WHERE k.user_id = $1
             AND m.timestamp > now() - interval '24 hours'"#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await?;

    Ok(format!(
        "Метрики: всего точек {}, уникальных имён {}, за 24ч — {}.",
        total.0, distinct.0, last24.0
    ))
}

async fn latest_metrics_block(
    pool: &sqlx::PgPool,
    user_id: uuid::Uuid,
) -> Result<String, sqlx::Error> {
    let latest = sqlx::query_as::<_, LatestNamedMetric>(
        r#"SELECT DISTINCT ON (m.name) m.name, m.value, m.timestamp
           FROM ingested_metrics m
           JOIN api_keys k ON m.api_key_id = k.id
           WHERE k.user_id = $1
           ORDER BY m.name, m.timestamp DESC
           LIMIT 8"#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await?;

    if latest.is_empty() {
        return Ok("Последние метрики: данных пока нет.".into());
    }
    let lines: Vec<String> = latest
        .iter()
        .map(|r| format!("· {} = {} ({})", r.name, r.value, r.timestamp.format("%Y-%m-%d %H:%M UTC")))
        .collect();
    Ok(format!("Последние по имени:\n{}", lines.join("\n")))
}

async fn alert_logs_block(
    pool: &sqlx::PgPool,
    user_id: uuid::Uuid,
) -> Result<String, sqlx::Error> {
    let n: (i64,) = sqlx::query_as(
        r#"SELECT COUNT(*)::bigint
           FROM ingested_logs l
           JOIN api_keys k ON l.api_key_id = k.id
           WHERE k.user_id = $1
             AND l.timestamp > now() - interval '24 hours'
             AND lower(l.level) IN ('error', 'critical', 'fatal')"#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await?;
    Ok(format!(
        "Логи уровня error/critical/fatal за 24ч: {} записей.",
        n.0
    ))
}

pub async fn pull(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let api_key = match header_str(&req, "X-API-Key") {
        Some(s) if !s.trim().is_empty() => s.trim(),
        _ => return bad("Missing X-API-Key"),
    };
    let module_token = match header_str(&req, "X-VK-Module-Token") {
        Some(s) if !s.trim().is_empty() => s.trim(),
        _ => return bad("Missing X-VK-Module-Token"),
    };
    let secret = match header_str(&req, "X-VK-Module-Secret") {
        Some(s) if !s.is_empty() => s,
        _ => return bad("Missing X-VK-Module-Secret"),
    };

    let key_row: Option<(uuid::Uuid, uuid::Uuid)> = sqlx::query_as(
        "SELECT id, user_id FROM api_keys WHERE key = $1",
    )
    .bind(api_key)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    let Some((_key_id, user_id)) = key_row else {
        return bad("Invalid API key");
    };

    let row: Option<(String, serde_json::Value)> = sqlx::query_as(
        r#"SELECT password_hash, selected_functions
           FROM vk_web_module
           WHERE user_id = $1 AND id_token = $2"#,
    )
    .bind(user_id)
    .bind(module_token)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    let Some((hash, funcs_json)) = row else {
        return bad("Unknown module token");
    };

    let ok = match blocking::bcrypt_verify_password(secret, &hash).await {
        Ok(v) => v,
        Err(e) => {
            log::error!("vk_bot_pull bcrypt: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Verification error".into(),
            });
        }
    };
    if !ok {
        return bad("Invalid module secret");
    }

    let features = normalized_features(&funcs_json);
    let mut parts: Vec<String> = Vec::new();
    parts.push("Waypoint · дайджест".to_string());

    for f in &features {
        let block = match *f {
            "metrics_digest" => metrics_digest_block(&state.pool, user_id).await,
            "latest_metrics" => latest_metrics_block(&state.pool, user_id).await,
            "alert_logs_digest" => alert_logs_block(&state.pool, user_id).await,
            "connection_ok" => Ok(format!(
                "Связь: OK (UTC {}).",
                Utc::now().format("%Y-%m-%d %H:%M")
            )),
            "host_metrics_hint" => Ok(
                "Хост: подключите scripts/waypoint_host_install_linux.sh — метрики host.load1, host.mem_used_percent, host.disk_root_used_percent."
                    .into(),
            ),
            _ => continue,
        };
        match block {
            Ok(s) => parts.push(s),
            Err(e) => {
                log::error!("vk_bot_pull block {}: {}", f, e);
                return HttpResponse::InternalServerError().json(ErrorResponse {
                    error: "Failed to build digest".into(),
                });
            }
        }
    }

    let message = parts.join("\n\n");
    HttpResponse::Ok().json(json!({
        "ok": true,
        "message": message,
    }))
}
