use actix_web::{web, HttpResponse, Responder, HttpRequest};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use sqlx::{PgPool, FromRow};
use crate::{authz, ErrorResponse};

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct Version {
    pub id: Uuid,
    pub version_type: String,
    pub version: String,
    pub artifact_url: String,
    pub changelog: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Deserialize)]
pub struct CreateVersionRequest {
    pub version_type: String,
    pub version: String,
    pub artifact_url: String,
    pub changelog: Option<String>,
}

pub async fn list(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    query: web::Query<std::collections::HashMap<String, String>>,
) -> impl Responder {
    if let Err(resp) = authz::require_staff(pool.get_ref(), &req).await {
        return resp;
    }

    let version_type = query.get("type").map(|s| s.as_str());

    let versions = if let Some(typ) = version_type {
        sqlx::query_as::<_, Version>(
            "SELECT id, version_type, version, artifact_url, changelog, created_at FROM waypoint.versions WHERE version_type = $1 ORDER BY created_at DESC"
        )
        .bind(typ)
        .fetch_all(pool.get_ref())
        .await
    } else {
        sqlx::query_as::<_, Version>(
            "SELECT id, version_type, version, artifact_url, changelog, created_at FROM waypoint.versions ORDER BY created_at DESC"
        )
        .fetch_all(pool.get_ref())
        .await
    };

    match versions {
        Ok(rows) => HttpResponse::Ok().json(rows),
        Err(e) => {
            eprintln!("Failed to fetch versions: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to fetch versions".into(),
            })
        }
    }
}

pub async fn create(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    payload: web::Json<CreateVersionRequest>,
) -> impl Responder {
    if let Err(resp) = authz::require_nexus(pool.get_ref(), &req).await {
        return resp;
    }

    let id = Uuid::new_v4();

    let result = sqlx::query(
        "INSERT INTO waypoint.versions (id, version_type, version, artifact_url, changelog) VALUES ($1, $2, $3, $4, $5)"
    )
    .bind(id)
    .bind(&payload.version_type)
    .bind(&payload.version)
    .bind(&payload.artifact_url)
    .bind(&payload.changelog)
    .execute(pool.get_ref())
    .await;

    match result {
        Ok(_) => HttpResponse::Ok().json(serde_json::json!({
            "id": id.to_string(),
            "message": "Version created"
        })),
        Err(e) => {
            eprintln!("Failed to create version: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to create version".into(),
            })
        }
    }
}