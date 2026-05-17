use actix_web::{web, HttpRequest, HttpResponse, Responder};
use chrono::Utc;
use uuid::Uuid;

use super::ingest_payload::{
    dev_event_acceptable, log_acceptable, log_triggers_alert, metric_acceptable, normalize_dev_channel,
    IngestPayload, MAX_DEV_EVENTS_PER_REQUEST,
};
use crate::clickhouse_sink;
use crate::ErrorResponse;

pub async fn ingest_handler(
    req: HttpRequest,
    state: web::Data<crate::AppState>,
    payload: web::Json<IngestPayload>,
) -> impl Responder {
    let pool = &state.pool;
    let api_key = match req.headers().get("X-API-Key") {
        Some(h) => match h.to_str() {
            Ok(s) => s,
            Err(_) => {
                return HttpResponse::BadRequest().json(ErrorResponse {
                    error: "Invalid API key header".into(),
                })
            }
        },
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Missing API key".into(),
            })
        }
    };

    let key_record = sqlx::query_as::<_, (Uuid, Uuid)>("SELECT id, user_id FROM api_keys WHERE key = $1")
        .bind(api_key)
        .fetch_optional(pool)
        .await;

    let (api_key_id, user_id) = match key_record {
        Ok(Some((id, uid))) => (id, uid),
        Ok(None) => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid API key".into(),
            })
        }
        Err(e) => {
            eprintln!("Database error checking API key: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    if let Some(r) = &state.redis {
        let mut c = r.clone();
        let key = format!("nexus:ingest:rl:{}", api_key_id);
        match redis::cmd("INCR").arg(&key).query_async::<i64>(&mut c).await {
            Ok(n) => {
                if n == 1 {
                    let _: redis::RedisResult<bool> =
                        redis::cmd("EXPIRE").arg(&key).arg(60i64).query_async(&mut c).await;
                }
                if n > 50_000 {
                    return HttpResponse::TooManyRequests().json(ErrorResponse {
                        error: "Ingest rate limit exceeded (per API key, 60s window)".into(),
                    });
                }
            }
            Err(e) => log::warn!("redis ingest rate limit: {}", e),
        }
    }

    apply_ingest(state.get_ref(), api_key_id, user_id, payload.into_inner()).await
}

/// Запись ingest в БД (общий путь для X-API-Key и POST /me/ingest).
pub async fn apply_ingest(
    state: &crate::AppState,
    api_key_id: Uuid,
    user_id: Uuid,
    payload: IngestPayload,
) -> HttpResponse {
    let pool = &state.pool;

    let pool_clone = pool.clone();
    tokio::spawn(async move {
        let _ = sqlx::query("UPDATE api_keys SET last_used = now() WHERE id = $1")
            .bind(api_key_id)
            .execute(&pool_clone)
            .await;
    });

    let now = Utc::now();
    let mut metric_count = 0usize;
    let mut skipped_metrics = 0usize;
    for metric in &payload.metrics {
        if !metric_acceptable(metric) {
            skipped_metrics += 1;
            continue;
        }
        let ts = payload.timestamp.unwrap_or(now);
        let tags = metric.tags.as_ref().unwrap_or(&serde_json::Value::Null);
        if let Err(e) = sqlx::query(
            "INSERT INTO ingested_metrics (api_key_id, name, value, tags, timestamp) VALUES ($1, $2, $3, $4, $5)",
        )
        .bind(api_key_id)
        .bind(&metric.name)
        .bind(metric.value)
        .bind(tags)
        .bind(ts)
        .execute(pool)
        .await
        {
            eprintln!("Failed to insert metric {}: {}", metric.name, e);
        } else {
            metric_count += 1;
            if clickhouse_sink::enabled() {
                clickhouse_sink::spawn_sink_metrics(
                    state.http_client.clone(),
                    api_key_id,
                    user_id,
                    &metric.name,
                    metric.value,
                    tags,
                    ts,
                );
            }
        }
    }

    let mut log_count = 0usize;
    let mut skipped_logs = 0usize;
    if let Some(logs) = &payload.logs {
        for log in logs {
            if !log_acceptable(log) {
                skipped_logs += 1;
                continue;
            }
            let tags = log.tags.as_ref().unwrap_or(&serde_json::Value::Null);
            if let Err(e) = sqlx::query(
                "INSERT INTO ingested_logs (api_key_id, level, message, tags) VALUES ($1, $2, $3, $4)",
            )
            .bind(api_key_id)
            .bind(&log.level)
            .bind(&log.message)
            .bind(tags)
            .execute(pool)
            .await
            {
                eprintln!("Failed to insert log: {}", e);
            } else {
                log_count += 1;
                if clickhouse_sink::enabled() {
                    clickhouse_sink::spawn_sink_log(
                        state.http_client.clone(),
                        api_key_id,
                        user_id,
                        &log.level,
                        &log.message,
                        tags,
                        Utc::now(),
                    );
                }
                if log_triggers_alert(&log.level) {
                    let pool_cl = pool.clone();
                    let uid = user_id;
                    let msg = log.message.clone();
                    crate::alert::webhook_async("Lynx/Waypoint ingest: critical log", &msg);
                    crate::alert::metric_email_alert_async(
                        "Lynx / WaypointMetric: критический лог ingest",
                        &format!(
                            "Уровень: {}\nСообщение:\n{}\n\n(Уведомление с API Lynx; настройте WAYPOINT_ALERT_EMAIL_TO и OTP_WEBHOOK_URL.)",
                            log.level, msg
                        ),
                    );
                    tokio::spawn(async move {
                        crate::vk_notify::notify_user_metric_alert(
                            &pool_cl,
                            uid,
                            "Lynx: критический лог с сервера",
                            &msg,
                        )
                        .await;
                    });
                }
            }
        }
    }

    let mut dev_event_count = 0usize;
    let mut skipped_dev_events = 0usize;
    let ev_slice: &[super::ingest_payload::PayloadDevEvent] =
        if payload.events.len() > MAX_DEV_EVENTS_PER_REQUEST {
            skipped_dev_events += payload.events.len() - MAX_DEV_EVENTS_PER_REQUEST;
            &payload.events[..MAX_DEV_EVENTS_PER_REQUEST]
        } else {
            &payload.events[..]
        };
    let ts_ev = payload.timestamp.unwrap_or(now);
    for ev in ev_slice {
        if !dev_event_acceptable(ev) {
            skipped_dev_events += 1;
            continue;
        }
        let ch = normalize_dev_channel(&ev.channel);
        let props = ev.properties.as_ref().unwrap_or(&serde_json::Value::Null);
        if let Err(e) = sqlx::query(
            "INSERT INTO waypoint_dev_events (api_key_id, channel, event_name, value, properties, \"timestamp\") VALUES ($1, $2, $3, $4, $5, $6)",
        )
        .bind(api_key_id)
        .bind(&ch)
        .bind(ev.event.trim())
        .bind(ev.value)
        .bind(props)
        .bind(ts_ev)
        .execute(pool)
        .await
        {
            eprintln!("Failed to insert dev event {}: {}", ev.event, e);
        } else {
            dev_event_count += 1;
        }
    }

    if let Some(pm) = &state.prometheus {
        pm.ingest_metrics_accepted.inc_by(metric_count as u64);
        pm.ingest_logs_accepted.inc_by(log_count as u64);
        pm.ingest_metrics_rejected.inc_by(skipped_metrics as u64);
        pm.ingest_logs_rejected.inc_by(skipped_logs as u64);
    }

    HttpResponse::Ok().json(serde_json::json!({
        "status": "ok",
        "ingested_metrics": metric_count,
        "ingested_logs": log_count,
        "ingested_dev_events": dev_event_count,
        "skipped_metrics": skipped_metrics,
        "skipped_logs": skipped_logs,
        "skipped_dev_events": skipped_dev_events,
    }))
}
