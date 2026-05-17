use actix_web::{web, HttpResponse, Responder, HttpRequest};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use sqlx::{PgPool, FromRow};
use chrono::{DateTime, Utc};

use crate::{ErrorResponse, get_user_id_from_token};

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct Instance {
    pub id: Uuid,
    pub owner_id: Uuid,
    pub name: String,
    pub instance_type: String,
    pub status: String,
    pub version: Option<String>,
    pub config: serde_json::Value,
    pub metadata: serde_json::Value,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct CreateInstanceRequest {
    pub name: String,
    pub instance_type: String,
    pub config: Option<serde_json::Value>,
    pub metadata: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateInstanceRequest {
    pub name: Option<String>,
    pub status: Option<String>,
    pub version: Option<String>,
    pub config: Option<serde_json::Value>,
    pub metadata: Option<serde_json::Value>,
}

pub async fn list(
    req: HttpRequest,
    pool: web::Data<PgPool>,
) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };

    let instances = sqlx::query_as::<_, Instance>(
        "SELECT id, owner_id, name, instance_type, status, version, config, metadata, created_at, updated_at FROM waypoint.instances WHERE owner_id = $1"
    )
    .bind(user_id)
    .fetch_all(pool.get_ref())
    .await;

    match instances {
        Ok(rows) => HttpResponse::Ok().json(rows),
        Err(e) => {
            eprintln!("Failed to fetch instances: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to fetch instances".into(),
            })
        }
    }
}

pub async fn create(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    payload: web::Json<CreateInstanceRequest>,
) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };

    let id = Uuid::new_v4();
    let config = payload.config.clone().unwrap_or(serde_json::json!({}));
    let metadata = payload.metadata.clone().unwrap_or(serde_json::json!({}));

    let result = sqlx::query(
        "INSERT INTO waypoint.instances (id, owner_id, name, instance_type, config, metadata) VALUES ($1, $2, $3, $4, $5, $6)"
    )
    .bind(id)
    .bind(user_id)
    .bind(&payload.name)
    .bind(&payload.instance_type)
    .bind(config)
    .bind(metadata)
    .execute(pool.get_ref())
    .await;

    match result {
        Ok(_) => {
            HttpResponse::Ok().json(serde_json::json!({
                "id": id.to_string(),
                "message": "Instance created"
            }))
        }
        Err(e) => {
            eprintln!("Failed to create instance: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to create instance".into(),
            })
        }
    }
}

pub async fn get(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<Uuid>,
) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };

    let instance_id = path.into_inner();

    let instance = sqlx::query_as::<_, Instance>(
        "SELECT id, owner_id, name, instance_type, status, version, config, metadata, created_at, updated_at FROM waypoint.instances WHERE id = $1 AND owner_id = $2"
    )
    .bind(instance_id)
    .bind(user_id)
    .fetch_optional(pool.get_ref())
    .await;

    match instance {
        Ok(Some(row)) => HttpResponse::Ok().json(row),
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "Instance not found".into(),
        }),
        Err(e) => {
            eprintln!("Failed to fetch instance: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to fetch instance".into(),
            })
        }
    }
}

pub async fn update(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<Uuid>,
    payload: web::Json<UpdateInstanceRequest>,
) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };

    let instance_id = path.into_inner();

    let owner_check = sqlx::query_scalar::<_, Uuid>("SELECT owner_id FROM waypoint.instances WHERE id = $1")
        .bind(instance_id)
        .fetch_optional(pool.get_ref())
        .await;

    match owner_check {
        Ok(Some(owner_id)) if owner_id == user_id => {}
        Ok(Some(_)) => return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        }),
        Ok(None) => return HttpResponse::NotFound().json(ErrorResponse {
            error: "Instance not found".into(),
        }),
        Err(e) => {
            eprintln!("Database error: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    }

    if let Some(name) = &payload.name {
        if let Err(e) = sqlx::query("UPDATE waypoint.instances SET name = $1, updated_at = now() WHERE id = $2")
            .bind(name)
            .bind(instance_id)
            .execute(pool.get_ref())
            .await
        {
            eprintln!("Failed to update name: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update instance".into(),
            });
        }
    }
    if let Some(status) = &payload.status {
        if let Err(e) = sqlx::query("UPDATE waypoint.instances SET status = $1, updated_at = now() WHERE id = $2")
            .bind(status)
            .bind(instance_id)
            .execute(pool.get_ref())
            .await
        {
            eprintln!("Failed to update status: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update instance".into(),
            });
        }
    }
    if let Some(version) = &payload.version {
        if let Err(e) = sqlx::query("UPDATE waypoint.instances SET version = $1, updated_at = now() WHERE id = $2")
            .bind(version)
            .bind(instance_id)
            .execute(pool.get_ref())
            .await
        {
            eprintln!("Failed to update version: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update instance".into(),
            });
        }
    }
    if let Some(config) = &payload.config {
        if let Err(e) = sqlx::query("UPDATE waypoint.instances SET config = $1, updated_at = now() WHERE id = $2")
            .bind(config)
            .bind(instance_id)
            .execute(pool.get_ref())
            .await
        {
            eprintln!("Failed to update config: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update instance".into(),
            });
        }
    }
    if let Some(metadata) = &payload.metadata {
        if let Err(e) = sqlx::query("UPDATE waypoint.instances SET metadata = $1, updated_at = now() WHERE id = $2")
            .bind(metadata)
            .bind(instance_id)
            .execute(pool.get_ref())
            .await
        {
            eprintln!("Failed to update metadata: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update instance".into(),
            });
        }
    }

    HttpResponse::Ok().json(serde_json::json!({"message": "Instance updated"}))
}

pub async fn delete(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<Uuid>,
) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };

    let instance_id = path.into_inner();

    let result = sqlx::query("DELETE FROM waypoint.instances WHERE id = $1 AND owner_id = $2")
        .bind(instance_id)
        .bind(user_id)
        .execute(pool.get_ref())
        .await;

    match result {
        Ok(rows) if rows.rows_affected() > 0 => {
            HttpResponse::Ok().json(serde_json::json!({"message": "Instance deleted"}))
        }
        Ok(_) => HttpResponse::NotFound().json(ErrorResponse {
            error: "Instance not found".into(),
        }),
        Err(e) => {
            eprintln!("Failed to delete instance: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to delete instance".into(),
            })
        }
    }
}