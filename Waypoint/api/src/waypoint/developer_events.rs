use actix_web::{web, HttpRequest, HttpResponse, Responder};
use chrono::{DateTime, Utc};
use serde::Deserialize;
use serde_json::json;
use uuid::Uuid;

use crate::{get_user_id_from_token, ErrorResponse};

#[derive(Debug, Deserialize)]
pub struct ListQuery {
    pub limit: Option<i64>,
    pub channel: Option<String>,
}

#[derive(serde::Serialize, sqlx::FromRow)]
pub struct DevEventRow {
    pub id: i64,
    pub api_key_id: Uuid,
    pub channel: String,
    pub event_name: String,
    pub value: Option<f64>,
    pub properties: Option<serde_json::Value>,
    pub timestamp: DateTime<Utc>,
}

pub async fn list(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
    q: web::Query<ListQuery>,
) -> impl Responder {
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

    let limit = q.limit.unwrap_or(50).clamp(1, 500);
    let channel_filter = q
        .channel
        .as_ref()
        .map(|s| s.trim().to_lowercase())
        .filter(|s| !s.is_empty());

    let rows = sqlx::query_as::<_, DevEventRow>(
        r#"SELECT e.id, e.api_key_id, e.channel, e.event_name, e.value, e.properties, e.timestamp
           FROM waypoint_dev_events e
           INNER JOIN api_keys k ON e.api_key_id = k.id
           WHERE k.user_id = $1
             AND ($2::text IS NULL OR e.channel = $2)
           ORDER BY e.timestamp DESC
           LIMIT $3"#,
    )
    .bind(user_id)
    .bind(channel_filter)
    .bind(limit)
    .fetch_all(pool.get_ref())
    .await;

    match rows {
        Ok(r) => HttpResponse::Ok().json(json!({ "items": r })),
        Err(e) => {
            log::error!("developer_events list: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load developer events".into(),
            })
        }
    }
}
