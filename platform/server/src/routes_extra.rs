use actix_web::{web, HttpRequest, HttpResponse, Responder};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, Instant};
use uuid::Uuid;

use crate::{get_user_id_from_token, AppState, ErrorResponse};

fn vk_bind_rate_map() -> &'static Mutex<HashMap<String, (Instant, u32)>> {
    static MAP: OnceLock<Mutex<HashMap<String, (Instant, u32)>>> = OnceLock::new();
    MAP.get_or_init(|| Mutex::new(HashMap::new()))
}

const VK_BIND_PER_MINUTE: u32 = 30;

fn client_ip_key(req: &HttpRequest) -> String {
    if let Some(xff) = req.headers().get("x-forwarded-for").and_then(|h| h.to_str().ok()) {
        let first = xff.split(',').next().unwrap_or("").trim();
        if !first.is_empty() {
            return first.to_string();
        }
    }
    req.connection_info()
        .peer_addr()
        .map(|s| s.to_string())
        .unwrap_or_else(|| "unknown".into())
}

fn check_vk_bind_rate(ip: &str) -> Result<(), HttpResponse> {
    let mut m = vk_bind_rate_map().lock().map_err(|_| {
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Service busy".into(),
        })
    })?;
    let now = Instant::now();
    let window = Duration::from_secs(60);
    let e = m.entry(ip.to_string()).or_insert((now, 0));
    if now.duration_since(e.0) > window {
        *e = (now, 0);
    }
    if e.1 >= VK_BIND_PER_MINUTE {
        return Err(
            HttpResponse::TooManyRequests().json(ErrorResponse {
                error: "Too many bind attempts".into(),
            }),
        );
    }
    e.1 += 1;
    Ok(())
}

#[derive(Serialize, sqlx::FromRow)]
struct MetricRow {
    name: String,
    value: f64,
    tags: Option<serde_json::Value>,
    timestamp: DateTime<Utc>,
}

#[derive(Serialize, sqlx::FromRow)]
struct LogRow {
    level: String,
    message: String,
    tags: Option<serde_json::Value>,
    timestamp: DateTime<Utc>,
}

pub async fn my_metrics(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let rows = sqlx::query_as::<_, MetricRow>(
        r#"SELECT m.name, m.value, m.tags, m.timestamp
           FROM ingested_metrics m
           JOIN api_keys k ON m.api_key_id = k.id
           WHERE k.user_id = $1
           ORDER BY m.timestamp DESC
           LIMIT 500"#,
    )
    .bind(user_id)
    .fetch_all(&state.pool)
    .await;

    match rows {
        Ok(r) => HttpResponse::Ok().json(r),
        Err(e) => {
            log::error!("my_metrics: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load metrics".into(),
            })
        }
    }
}

pub async fn my_logs(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let rows = sqlx::query_as::<_, LogRow>(
        r#"SELECT l.level, l.message, l.tags, l.timestamp
           FROM ingested_logs l
           JOIN api_keys k ON l.api_key_id = k.id
           WHERE k.user_id = $1
           ORDER BY l.timestamp DESC
           LIMIT 200"#,
    )
    .bind(user_id)
    .fetch_all(&state.pool)
    .await;

    match rows {
        Ok(r) => HttpResponse::Ok().json(r),
        Err(e) => {
            log::error!("my_logs: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load logs".into(),
            })
        }
    }
}

pub async fn my_system_metrics(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let agent_key: Option<String> = match sqlx::query_scalar(
        "SELECT agent_api_key FROM user_workspace WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(&state.pool)
    .await
    {
        Ok(v) => v,
        Err(e) => {
            log::error!("my_system_metrics: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load system metrics".into(),
            });
        }
    };

    let key_trimmed = agent_key
        .as_ref()
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string());

    let mut points: Vec<crate::MetricPoint> = Vec::new();
    if let Some(ref k) = key_trimmed {
        let store = state.connected_metrics.lock().await;
        points = store.get_points_for_agent(k);
    }

    let fb = std::env::var("NEXUS_SYSTEM_METRICS_FALLBACK").unwrap_or_default();
    let fallback =
        !(fb.trim() == "0" || fb.trim().eq_ignore_ascii_case("false") || fb.trim().eq_ignore_ascii_case("no"));
    if points.is_empty() && fallback {
        let g = state.metrics.lock().await;
        points = g.get_points();
    }

    HttpResponse::Ok().json(points)
}

pub async fn ingest_simulate(_state: web::Data<AppState>, req: HttpRequest, body: web::Json<crate::waypoint::ingest_payload::IngestPayload>) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    if get_user_id_from_token(&req, &jwt_secret).is_none() {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        });
    }

    HttpResponse::Ok().json(crate::waypoint::ingest_analysis::dry_run_report(&*body))
}

#[derive(Serialize, sqlx::FromRow)]
struct LatestNamedMetric {
    name: String,
    value: f64,
    timestamp: DateTime<Utc>,
}

pub async fn my_metrics_summary(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let total: (i64,) = match sqlx::query_as(
        r#"SELECT COUNT(*)::bigint
           FROM ingested_metrics m
           JOIN api_keys k ON m.api_key_id = k.id
           WHERE k.user_id = $1"#,
    )
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    {
        Ok(t) => t,
        Err(e) => {
            log::error!("my_metrics_summary total: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load summary".into(),
            });
        }
    };

    let distinct: (i64,) = match sqlx::query_as(
        r#"SELECT COUNT(DISTINCT m.name)::bigint
           FROM ingested_metrics m
           JOIN api_keys k ON m.api_key_id = k.id
           WHERE k.user_id = $1"#,
    )
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    {
        Ok(t) => t,
        Err(e) => {
            log::error!("my_metrics_summary distinct: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load summary".into(),
            });
        }
    };

    let last24: (i64,) = match sqlx::query_as(
        r#"SELECT COUNT(*)::bigint
           FROM ingested_metrics m
           JOIN api_keys k ON m.api_key_id = k.id
           WHERE k.user_id = $1
             AND m.timestamp > now() - interval '24 hours'"#,
    )
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    {
        Ok(t) => t,
        Err(e) => {
            log::error!("my_metrics_summary last24: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load summary".into(),
            });
        }
    };

    let alert_logs_24h: (i64,) = match sqlx::query_as(
        r#"SELECT COUNT(*)::bigint
           FROM ingested_logs l
           JOIN api_keys k ON l.api_key_id = k.id
           WHERE k.user_id = $1
             AND l.timestamp > now() - interval '24 hours'
             AND lower(l.level) IN ('error', 'critical', 'fatal')"#,
    )
    .bind(user_id)
    .fetch_one(&state.pool)
    .await
    {
        Ok(t) => t,
        Err(e) => {
            log::error!("my_metrics_summary alerts: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load summary".into(),
            });
        }
    };

    let latest = match sqlx::query_as::<_, LatestNamedMetric>(
        r#"SELECT DISTINCT ON (m.name) m.name, m.value, m.timestamp
           FROM ingested_metrics m
           JOIN api_keys k ON m.api_key_id = k.id
           WHERE k.user_id = $1
           ORDER BY m.name, m.timestamp DESC
           LIMIT 12"#,
    )
    .bind(user_id)
    .fetch_all(&state.pool)
    .await
    {
        Ok(rows) => rows,
        Err(e) => {
            log::error!("my_metrics_summary latest: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load summary".into(),
            });
        }
    };

    HttpResponse::Ok().json(json!({
        "total_points": total.0,
        "unique_metric_names": distinct.0,
        "points_last_24h": last24.0,
        "alert_logs_last_24h": alert_logs_24h.0,
        "latest_by_name": latest,
    }))
}

#[derive(Serialize, sqlx::FromRow)]
struct WaypointUsageDay {
    day: chrono::NaiveDate,
    metrics: i64,
    logs: i64,
}

#[derive(Serialize, sqlx::FromRow)]
struct WaypointKeyUsage {
    id: Uuid,
    name: String,
    last_used: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    metrics_30d: i64,
    logs_30d: i64,
    dev_events_30d: i64,
}

pub async fn my_waypoint_usage(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let window_days: i64 = std::env::var("WAYPOINT_USAGE_WINDOW_DAYS")
        .ok()
        .and_then(|s| s.parse().ok())
        .filter(|&d| d > 0 && d <= 366)
        .unwrap_or(30);

    let quota_metrics_month: i64 = std::env::var("WAYPOINT_QUOTA_METRICS_MONTH")
        .ok()
        .and_then(|s| s.parse().ok())
        .filter(|&n| n > 0)
        .unwrap_or(10_000_000);
    let quota_logs_month: i64 = std::env::var("WAYPOINT_QUOTA_LOG_LINES_MONTH")
        .ok()
        .and_then(|s| s.parse().ok())
        .filter(|&n| n > 0)
        .unwrap_or(5_000_000);
    let ingest_rpm_per_key: i64 = std::env::var("WAYPOINT_INGEST_RPM_PER_KEY")
        .ok()
        .and_then(|s| s.parse().ok())
        .filter(|&n| n > 0)
        .unwrap_or(50_000);

    let totals: Result<(i64, i64, i64), _> = sqlx::query_as(
        r#"SELECT
             (SELECT COUNT(*)::bigint FROM ingested_metrics m
                INNER JOIN api_keys k ON m.api_key_id = k.id
                WHERE k.user_id = $1
                  AND m.timestamp >= NOW() - ($2::bigint * INTERVAL '1 day')),
             (SELECT COUNT(*)::bigint FROM ingested_logs l
                INNER JOIN api_keys k ON l.api_key_id = k.id
                WHERE k.user_id = $1
                  AND l.timestamp >= NOW() - ($2::bigint * INTERVAL '1 day')),
             (SELECT COUNT(*)::bigint FROM waypoint_dev_events e
                INNER JOIN api_keys k ON e.api_key_id = k.id
                WHERE k.user_id = $1
                  AND e.timestamp >= NOW() - ($2::bigint * INTERVAL '1 day'))"#,
    )
    .bind(user_id)
    .bind(window_days)
    .fetch_one(&state.pool)
    .await;

    let (metrics_window, logs_window, dev_events_window) = match totals {
        Ok(t) => t,
        Err(e) => {
            log::error!("my_waypoint_usage totals: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load usage".into(),
            });
        }
    };

    let days = sqlx::query_as::<_, WaypointUsageDay>(
        r#"WITH bounds AS (
             SELECT (CURRENT_DATE - (($2::bigint - 1) * INTERVAL '1 day'))::date AS start_d,
                    CURRENT_DATE::date AS end_d
           ),
           days AS (
             SELECT generate_series(bounds.start_d, bounds.end_d, '1 day'::interval)::date AS d
             FROM bounds
           )
           SELECT days.d AS day,
                  COALESCE(mc.c, 0)::bigint AS metrics,
                  COALESCE(lc.c, 0)::bigint AS logs
           FROM days
           LEFT JOIN (
             SELECT (m.timestamp AT TIME ZONE 'UTC')::date AS d, COUNT(*)::bigint AS c
             FROM ingested_metrics m
             INNER JOIN api_keys k ON m.api_key_id = k.id
             WHERE k.user_id = $1
               AND m.timestamp >= NOW() - ($2::bigint * INTERVAL '1 day')
             GROUP BY 1
           ) mc ON mc.d = days.d
           LEFT JOIN (
             SELECT (l.timestamp AT TIME ZONE 'UTC')::date AS d, COUNT(*)::bigint AS c
             FROM ingested_logs l
             INNER JOIN api_keys k ON l.api_key_id = k.id
             WHERE k.user_id = $1
               AND l.timestamp >= NOW() - ($2::bigint * INTERVAL '1 day')
             GROUP BY 1
           ) lc ON lc.d = days.d
           ORDER BY days.d"#,
    )
    .bind(user_id)
    .bind(window_days)
    .fetch_all(&state.pool)
    .await;

    let by_day = match days {
        Ok(d) => d,
        Err(e) => {
            log::error!("my_waypoint_usage by_day: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load usage series".into(),
            });
        }
    };

    let keys_usage = sqlx::query_as::<_, WaypointKeyUsage>(
        r#"SELECT k.id, k.name, k.last_used, k.created_at,
             (SELECT COUNT(*)::bigint FROM ingested_metrics m
              WHERE m.api_key_id = k.id
                AND m.timestamp >= NOW() - ($2::bigint * INTERVAL '1 day')) AS metrics_30d,
             (SELECT COUNT(*)::bigint FROM ingested_logs l
              WHERE l.api_key_id = k.id
                AND l.timestamp >= NOW() - ($2::bigint * INTERVAL '1 day')) AS logs_30d,
             (SELECT COUNT(*)::bigint FROM waypoint_dev_events e
              WHERE e.api_key_id = k.id
                AND e.timestamp >= NOW() - ($2::bigint * INTERVAL '1 day')) AS dev_events_30d
           FROM api_keys k
           WHERE k.user_id = $1
           ORDER BY k.created_at DESC"#,
    )
    .bind(user_id)
    .bind(window_days)
    .fetch_all(&state.pool)
    .await;

    let by_api_key = match keys_usage {
        Ok(k) => k,
        Err(e) => {
            log::error!("my_waypoint_usage keys: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load per-key usage".into(),
            });
        }
    };

    HttpResponse::Ok().json(json!({
        "window_days": window_days,
        "totals": { "metrics": metrics_window, "logs": logs_window, "dev_events": dev_events_window },
        "by_day": by_day,
        "by_api_key": by_api_key,
        "quotas": {
            "metrics_per_month_soft_cap": quota_metrics_month,
            "log_lines_per_month_soft_cap": quota_logs_month,
            "ingest_rpm_per_api_key_cap": ingest_rpm_per_key,
            "note": "Лимиты для отображения в консоли; жёсткий rate limit ingest — отдельно (Redis, 60s window)."
        }
    }))
}

#[derive(Serialize, sqlx::FromRow)]
struct RegLogRow {
    id: Uuid,
    user_id: Uuid,
    email: String,
    nickname: String,
    created_at: DateTime<Utc>,
}

pub async fn admin_registration_log(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let admin_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };
    if !crate::is_admin(&state.pool, admin_id).await {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let rows = sqlx::query_as::<_, RegLogRow>(
        "SELECT id, user_id, email, nickname, created_at FROM registration_log ORDER BY created_at DESC LIMIT 500",
    )
    .fetch_all(&state.pool)
    .await;

    match rows {
        Ok(r) => HttpResponse::Ok().json(r),
        Err(e) => {
            log::error!("admin_registration_log: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

#[derive(Deserialize)]
pub struct VkBindBody {
    pub secret: String,
    pub code: String,
    pub peer_id: i64,
}

pub async fn vk_bot_bind(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<VkBindBody>,
) -> impl Responder {
    if let Err(resp) = check_vk_bind_rate(&client_ip_key(&req)) {
        return resp;
    }
    let expected = match std::env::var("VK_BOT_SECRET") {
        Ok(s) if !s.is_empty() => s,
        _ => {
            return HttpResponse::ServiceUnavailable().json(ErrorResponse {
                error: "VK_BOT_SECRET not configured".into(),
            })
        }
    };
    if body.secret != expected {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid secret".into(),
        });
    }

    let row: Option<(Uuid,)> = sqlx::query_as(
        "SELECT user_id FROM vk_bind_codes WHERE code = $1 AND expires_at > now()",
    )
    .bind(&body.code)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    let Some((user_id,)) = row else {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid or expired code".into(),
        });
    };

    let _ = sqlx::query(
        "INSERT INTO user_vk_peers (user_id, peer_id) VALUES ($1, $2)
         ON CONFLICT (user_id) DO UPDATE SET peer_id = $2, updated_at = now()",
    )
    .bind(user_id)
    .bind(body.peer_id)
    .execute(&state.pool)
    .await;

    let _ = sqlx::query("DELETE FROM vk_bind_codes WHERE user_id = $1")
        .bind(user_id)
        .execute(&state.pool)
        .await;

    HttpResponse::Ok().json(json!({"ok": true, "user_id": user_id.to_string()}))
}

pub async fn vk_integration_health(state: web::Data<AppState>) -> impl Responder {
    HttpResponse::Ok().json(crate::vk_notify::integration_health(&state.pool).await)
}

pub async fn profile_vk_code(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let u = Uuid::new_v4().as_simple().to_string();
    let code = format!("NX{}", &u[..8]);
    let exp = Utc::now() + chrono::Duration::minutes(15);

    let _ = sqlx::query(
        "INSERT INTO vk_bind_codes (user_id, code, expires_at) VALUES ($1, $2, $3)
         ON CONFLICT (user_id) DO UPDATE SET code = $2, expires_at = $3",
    )
    .bind(user_id)
    .bind(&code)
    .bind(exp)
    .execute(&state.pool)
    .await;

    HttpResponse::Ok().json(json!({
        "code": code,
        "expires_at": exp,
        "hint": "Напишите боту ВК: привязать <код>"
    }))
}

#[derive(Serialize)]
struct ChatUserRow {
    id: String,
    nickname: String,
    full_name: String,
}

pub async fn chat_users(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let my_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let rows = sqlx::query_as::<_, (Uuid, String, String)>(
        r#"SELECT u.id, u.nickname, u.full_name FROM users u
           INNER JOIN friendships f ON f.status = 'accepted'
             AND ((f.requester_id = $1 AND f.addressee_id = u.id)
               OR (f.addressee_id = $1 AND f.requester_id = u.id))
           WHERE COALESCE(u.blocked, false) = false
             AND NOT EXISTS (
               SELECT 1 FROM chat_blocks b
               WHERE (b.blocker_id = $1 AND b.blocked_id = u.id)
                  OR (b.blocker_id = u.id AND b.blocked_id = $1)
             )
           ORDER BY u.nickname
           LIMIT 200"#,
    )
    .bind(my_id)
    .fetch_all(&state.pool)
    .await;

    match rows {
        Ok(r) => {
            let out: Vec<ChatUserRow> = r
                .into_iter()
                .map(|(id, nickname, full_name)| ChatUserRow {
                    id: id.to_string(),
                    nickname,
                    full_name,
                })
                .collect();
            HttpResponse::Ok().json(out)
        }
        Err(e) => {
            log::error!("chat_users: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

#[derive(Deserialize)]
pub struct ChatSendBody {
    pub to: Uuid,
    #[serde(default)]
    pub body: Option<String>,
    #[serde(default)]
    pub e2ee: Option<ChatE2eePayload>,
}

#[derive(Deserialize)]
pub struct ChatE2eePayload {
    pub algorithm: String,
    pub nonce_b64: String,
    pub ciphertext_b64: String,
    pub sender_pub_b64: String,
}

#[derive(Deserialize)]
pub struct E2eePublicKeyBody {
    pub public_key_b64: String,
}

#[derive(Serialize)]
pub struct E2eePublicKeyOut {
    pub user_id: String,
    pub public_key_b64: String,
}

pub async fn chat_send(state: web::Data<AppState>, req: HttpRequest, body: web::Json<ChatSendBody>) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let sender = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let mut plain_text: Option<String> = None;
    let mut e2ee_alg: Option<String> = None;
    let mut e2ee_nonce: Option<String> = None;
    let mut e2ee_cipher: Option<String> = None;
    let mut e2ee_sender_key: Option<String> = None;

    match (&body.body, &body.e2ee) {
        (Some(t), None) => {
            let text = t.trim();
            if text.is_empty() || text.len() > 4000 {
                return HttpResponse::BadRequest().json(ErrorResponse {
                    error: "Invalid message".into(),
                });
            }
            plain_text = Some(text.to_string());
        }
        (None, Some(enc)) => {
            if enc.algorithm.trim() != "x25519-aesgcm-v1" {
                return HttpResponse::BadRequest().json(ErrorResponse {
                    error: "Unsupported e2ee algorithm".into(),
                });
            }
            if enc.nonce_b64.trim().is_empty()
                || enc.ciphertext_b64.trim().is_empty()
                || enc.sender_pub_b64.trim().is_empty()
            {
                return HttpResponse::BadRequest().json(ErrorResponse {
                    error: "Invalid e2ee payload".into(),
                });
            }
            if enc.nonce_b64.len() > 64 || enc.sender_pub_b64.len() > 128 || enc.ciphertext_b64.len() > 12000 {
                return HttpResponse::BadRequest().json(ErrorResponse {
                    error: "e2ee payload too large".into(),
                });
            }
            e2ee_alg = Some(enc.algorithm.trim().to_string());
            e2ee_nonce = Some(enc.nonce_b64.trim().to_string());
            e2ee_cipher = Some(enc.ciphertext_b64.trim().to_string());
            e2ee_sender_key = Some(enc.sender_pub_b64.trim().to_string());
        }
        _ => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "Provide either body or e2ee payload".into(),
            })
        }
    }

    if sender == body.to {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Cannot message yourself".into(),
        });
    }

    let max_per_min: i64 = std::env::var("CHAT_MAX_MSG_PER_MINUTE")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(30);

    let sender_blocked: Option<(bool,)> = sqlx::query_as("SELECT COALESCE(blocked,false) FROM users WHERE id = $1")
        .bind(sender)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None);
    if sender_blocked.map(|(b,)| b).unwrap_or(true) {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Your account is restricted".into(),
        });
    }

    let recipient_row: Option<(bool,)> = sqlx::query_as("SELECT COALESCE(blocked,false) FROM users WHERE id = $1")
        .bind(body.to)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None);
    let Some((recip_blocked,)) = recipient_row else {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "User not found".into(),
        });
    };
    if recip_blocked {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Cannot message this user".into(),
        });
    }

    let blocked_pair: Option<(i64,)> = sqlx::query_as(
        r#"SELECT COUNT(*)::bigint FROM chat_blocks
           WHERE (blocker_id = $1 AND blocked_id = $2) OR (blocker_id = $2 AND blocked_id = $1)"#,
    )
    .bind(sender)
    .bind(body.to)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);
    if blocked_pair.map(|(c,)| c > 0).unwrap_or(false) {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Messaging is blocked between these users".into(),
        });
    }

    let friends: bool = sqlx::query_scalar(
        r#"SELECT EXISTS(
             SELECT 1 FROM friendships f
             WHERE f.status = 'accepted'
               AND ((f.requester_id = $1 AND f.addressee_id = $2)
                 OR (f.requester_id = $2 AND f.addressee_id = $1))
           )"#,
    )
    .bind(sender)
    .bind(body.to)
    .fetch_one(&state.pool)
    .await
    .unwrap_or(false);
    if !friends {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Only friends can chat — send a friend request first".into(),
        });
    }

    let recent: Option<(i64,)> = sqlx::query_as(
        r#"SELECT COUNT(*)::bigint FROM chat_messages
           WHERE sender_id = $1 AND created_at > now() - interval '1 minute'"#,
    )
    .bind(sender)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);
    if recent.map(|(c,)| c >= max_per_min).unwrap_or(false) {
        return HttpResponse::TooManyRequests().json(ErrorResponse {
            error: "Too many messages, slow down".into(),
        });
    }

    let mid = Uuid::new_v4();
    match sqlx::query(
        "INSERT INTO chat_messages (id, sender_id, recipient_id, body, e2ee_algorithm, e2ee_nonce, e2ee_ciphertext, e2ee_sender_key) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
    )
    .bind(mid)
    .bind(sender)
    .bind(body.to)
    .bind(plain_text)
    .bind(e2ee_alg)
    .bind(e2ee_nonce)
    .bind(e2ee_cipher)
    .bind(e2ee_sender_key)
    .execute(&state.pool)
    .await
    {
        Ok(_) => HttpResponse::Ok().json(json!({"id": mid.to_string()})),
        Err(e) => {
            log::error!("chat_send: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to send".into(),
            })
        }
    }
}

#[derive(Serialize, sqlx::FromRow)]
struct ChatMsgOut {
    id: Uuid,
    sender_id: Uuid,
    recipient_id: Uuid,
    body: Option<String>,
    e2ee_algorithm: Option<String>,
    e2ee_nonce: Option<String>,
    e2ee_ciphertext: Option<String>,
    e2ee_sender_key: Option<String>,
    created_at: DateTime<Utc>,
}

#[derive(Deserialize)]
pub struct ChatHistoryQuery {
    pub after: Option<DateTime<Utc>>,
}

pub async fn chat_history(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
    q: web::Query<ChatHistoryQuery>,
) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let me = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let other = path.into_inner();

    let friends: bool = sqlx::query_scalar(
        r#"SELECT EXISTS(
             SELECT 1 FROM friendships f
             WHERE f.status = 'accepted'
               AND ((f.requester_id = $1 AND f.addressee_id = $2)
                 OR (f.requester_id = $2 AND f.addressee_id = $1))
           )"#,
    )
    .bind(me)
    .bind(other)
    .fetch_one(&state.pool)
    .await
    .unwrap_or(false);
    if !friends {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Not friends with this user".into(),
        });
    }

    let pair_blocked: Option<(i64,)> = sqlx::query_as(
        r#"SELECT COUNT(*)::bigint FROM chat_blocks
           WHERE (blocker_id = $1 AND blocked_id = $2) OR (blocker_id = $2 AND blocked_id = $1)"#,
    )
    .bind(me)
    .bind(other)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);
    if pair_blocked.map(|(c,)| c > 0).unwrap_or(false) {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Chat is blocked".into(),
        });
    }

    let rows = if let Some(after) = q.after {
        sqlx::query_as::<_, ChatMsgOut>(
            r#"SELECT id, sender_id, recipient_id, body, e2ee_algorithm, e2ee_nonce, e2ee_ciphertext, e2ee_sender_key, created_at FROM chat_messages
               WHERE ((sender_id = $1 AND recipient_id = $2) OR (sender_id = $2 AND recipient_id = $1))
                 AND created_at > $3
               ORDER BY created_at ASC
               LIMIT 200"#,
        )
        .bind(me)
        .bind(other)
        .bind(after)
        .fetch_all(&state.pool)
        .await
    } else {
        sqlx::query_as::<_, ChatMsgOut>(
            r#"SELECT id, sender_id, recipient_id, body, e2ee_algorithm, e2ee_nonce, e2ee_ciphertext, e2ee_sender_key, created_at FROM chat_messages
               WHERE (sender_id = $1 AND recipient_id = $2) OR (sender_id = $2 AND recipient_id = $1)
               ORDER BY created_at ASC
               LIMIT 200"#,
        )
        .bind(me)
        .bind(other)
        .fetch_all(&state.pool)
        .await
    };

    match rows {
        Ok(r) => HttpResponse::Ok().json(r),
        Err(e) => {
            log::error!("chat_history: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

#[derive(Serialize, sqlx::FromRow)]
struct ChatRecentSqlRow {
    id: Uuid,
    sender_id: Uuid,
    recipient_id: Uuid,
    body: Option<String>,
    e2ee_algorithm: Option<String>,
    created_at: DateTime<Utc>,
    peer_id: Uuid,
    peer_nickname: String,
    peer_full_name: String,
}

pub async fn chat_recent_preview(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let me = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let rows = sqlx::query_as::<_, ChatRecentSqlRow>(
        r#"SELECT m.id, m.sender_id, m.recipient_id, m.body, m.e2ee_algorithm, m.created_at,
                  u.id AS peer_id, u.nickname AS peer_nickname, u.full_name AS peer_full_name
           FROM chat_messages m
           INNER JOIN users u ON u.id = CASE WHEN m.sender_id = $1 THEN m.recipient_id ELSE m.sender_id END
           WHERE (m.sender_id = $1 OR m.recipient_id = $1)
             AND COALESCE(u.blocked, false) = false
             AND EXISTS (
               SELECT 1 FROM friendships f
               WHERE f.status = 'accepted'
                 AND ((f.requester_id = $1 AND f.addressee_id = u.id)
                   OR (f.requester_id = u.id AND f.addressee_id = $1))
             )
             AND NOT EXISTS (
               SELECT 1 FROM chat_blocks b
               WHERE (b.blocker_id = $1 AND b.blocked_id = u.id)
                  OR (b.blocker_id = u.id AND b.blocked_id = $1)
             )
           ORDER BY m.created_at DESC
           LIMIT 15"#,
    )
    .bind(me)
    .fetch_all(&state.pool)
    .await;

    match rows {
        Ok(r) => {
            let out: Vec<serde_json::Value> = r
                .into_iter()
                .map(|row| {
                    let encrypted = row.e2ee_algorithm.is_some();
                    let title = if row.peer_full_name.trim().is_empty() {
                        row.peer_nickname.clone()
                    } else {
                        row.peer_full_name.clone()
                    };
                    let subtitle = if encrypted {
                        "Зашифрованное сообщение".to_string()
                    } else {
                        let b = row.body.unwrap_or_default();
                        if b.trim().is_empty() {
                            "…".to_string()
                        } else {
                            b
                        }
                    };
                    json!({
                        "message_id": row.id.to_string(),
                        "peer_id": row.peer_id.to_string(),
                        "title": title,
                        "subtitle": subtitle,
                        "created_at": row.created_at,
                        "is_encrypted": encrypted,
                        "is_outgoing": row.sender_id == me,
                    })
                })
                .collect();
            HttpResponse::Ok().json(out)
        }
        Err(e) => {
            log::error!("chat_recent_preview: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

pub async fn e2ee_set_public_key(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<E2eePublicKeyBody>,
) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let me = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let key = body.public_key_b64.trim();
    if key.is_empty() || key.len() > 128 {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid key".into(),
        });
    }

    match sqlx::query("UPDATE users SET e2ee_public_key = $1, e2ee_key_updated_at = now() WHERE id = $2")
        .bind(key)
        .bind(me)
        .execute(&state.pool)
        .await
    {
        Ok(_) => HttpResponse::Ok().json(json!({"ok": true})),
        Err(e) => {
            log::error!("e2ee_set_public_key: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

pub async fn e2ee_get_public_key(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    if get_user_id_from_token(&req, &jwt_secret).is_none() {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        });
    }

    let uid = path.into_inner();
    let row: Option<(Option<String>,)> = sqlx::query_as("SELECT e2ee_public_key FROM users WHERE id = $1")
        .bind(uid)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None);

    match row {
        Some((Some(key),)) if !key.is_empty() => HttpResponse::Ok().json(E2eePublicKeyOut {
            user_id: uid.to_string(),
            public_key_b64: key,
        }),
        Some(_) => HttpResponse::NotFound().json(ErrorResponse {
            error: "User has no e2ee key".into(),
        }),
        None => HttpResponse::NotFound().json(ErrorResponse {
            error: "User not found".into(),
        }),
    }
}

#[derive(Deserialize)]
pub struct ChatBlockBody {
    pub user_id: Uuid,
}

pub async fn chat_block_user(state: web::Data<AppState>, req: HttpRequest, body: web::Json<ChatBlockBody>) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let me = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };
    if me == body.user_id {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Cannot block yourself".into(),
        });
    }
    let exists: Option<(Uuid,)> = sqlx::query_as("SELECT id FROM users WHERE id = $1")
        .bind(body.user_id)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None);
    if exists.is_none() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "User not found".into(),
        });
    }
    match sqlx::query(
        "INSERT INTO chat_blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
    )
    .bind(me)
    .bind(body.user_id)
    .execute(&state.pool)
    .await
    {
        Ok(_) => HttpResponse::Ok().json(json!({"ok": true})),
        Err(e) => {
            log::error!("chat_block_user: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

pub async fn chat_unblock_user(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let me = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };
    let other = path.into_inner();
    let _ = sqlx::query("DELETE FROM chat_blocks WHERE blocker_id = $1 AND blocked_id = $2")
        .bind(me)
        .bind(other)
        .execute(&state.pool)
        .await;
    HttpResponse::Ok().json(json!({"ok": true}))
}
