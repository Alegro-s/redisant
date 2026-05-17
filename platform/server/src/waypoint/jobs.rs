use actix_web::{web, HttpResponse, Responder, HttpRequest};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use sqlx::{PgPool, FromRow};
use chrono::{DateTime, Utc};
use crate::{authz, ErrorResponse};

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct Job {
    pub id: Uuid,
    pub instance_id: Option<Uuid>,
    pub job_type: String,
    pub status: String,
    pub payload: Option<serde_json::Value>,
    pub result: Option<serde_json::Value>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct CreateJobRequest {
    pub instance_id: Option<Uuid>,
    pub job_type: String,
    pub payload: Option<serde_json::Value>,
}

pub async fn list(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    query: web::Query<std::collections::HashMap<String, String>>,
) -> impl Responder {
    if let Err(resp) = authz::require_staff(pool.get_ref(), &req).await {
        return resp;
    }

    let instance_id = query.get("instance_id").and_then(|s| Uuid::parse_str(s).ok());

    let jobs = if let Some(inst_id) = instance_id {
        sqlx::query_as::<_, Job>(
            "SELECT id, instance_id, job_type, status, payload, result, created_at, updated_at FROM waypoint.jobs WHERE instance_id = $1 ORDER BY created_at DESC"
        )
        .bind(inst_id)
        .fetch_all(pool.get_ref())
        .await
    } else {
        sqlx::query_as::<_, Job>(
            "SELECT id, instance_id, job_type, status, payload, result, created_at, updated_at FROM waypoint.jobs ORDER BY created_at DESC"
        )
        .fetch_all(pool.get_ref())
        .await
    };

    match jobs {
        Ok(rows) => HttpResponse::Ok().json(rows),
        Err(e) => {
            eprintln!("Failed to fetch jobs: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to fetch jobs".into(),
            })
        }
    }
}

pub async fn get(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<Uuid>,
) -> impl Responder {
    if let Err(resp) = authz::require_staff(pool.get_ref(), &req).await {
        return resp;
    }

    let job_id = path.into_inner();

    let job = sqlx::query_as::<_, Job>(
        "SELECT id, instance_id, job_type, status, payload, result, created_at, updated_at FROM waypoint.jobs WHERE id = $1"
    )
    .bind(job_id)
    .fetch_optional(pool.get_ref())
    .await;

    match job {
        Ok(Some(row)) => HttpResponse::Ok().json(row),
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "Job not found".into(),
        }),
        Err(e) => {
            eprintln!("Failed to fetch job: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to fetch job".into(),
            })
        }
    }
}

pub async fn create(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    payload: web::Json<CreateJobRequest>,
) -> impl Responder {
    if let Err(resp) = authz::require_staff(pool.get_ref(), &req).await {
        return resp;
    }

    let id = Uuid::new_v4();
    let payload_json = payload.payload.clone().unwrap_or(serde_json::json!({}));

    let result = sqlx::query(
        "INSERT INTO waypoint.jobs (id, instance_id, job_type, payload) VALUES ($1, $2, $3, $4)"
    )
    .bind(id)
    .bind(payload.instance_id)
    .bind(&payload.job_type)
    .bind(payload_json)
    .execute(pool.get_ref())
    .await;

    match result {
        Ok(_) => HttpResponse::Ok().json(serde_json::json!({
            "id": id.to_string(),
            "message": "Job created"
        })),
        Err(e) => {
            eprintln!("Failed to create job: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to create job".into(),
            })
        }
    }
}