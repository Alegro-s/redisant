use actix_web::{web, HttpResponse, Responder, HttpRequest};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use sqlx::PgPool;
use chrono::{DateTime, Utc};
use crate::{ErrorResponse, get_user_id_from_token}; // is_admin не нужен

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct ApiKey {
    pub id: Uuid,
    pub user_id: Uuid,
    pub name: String,
    pub key: String,
    pub last_used: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct ApiKeyPublic {
    pub id: Uuid,
    pub user_id: Uuid,
    pub name: String,
    pub key_masked: String,
    pub last_used: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
}

fn mask_ingest_api_key(raw: &str) -> String {
    if raw.len() <= 12 {
        return "wpk_•••".to_string();
    }
    let head = &raw[..10.min(raw.len())];
    let tail = &raw[raw.len().saturating_sub(4)..];
    format!("{}…{}", head, tail)
}

fn to_public(row: ApiKey) -> ApiKeyPublic {
    let key_masked = mask_ingest_api_key(&row.key);
    ApiKeyPublic {
        id: row.id,
        user_id: row.user_id,
        name: row.name,
        key_masked,
        last_used: row.last_used,
        created_at: row.created_at,
    }
}

#[derive(Debug, Deserialize)]
pub struct CreateApiKeyRequest {
    pub name: String,
}

#[derive(Debug, Deserialize)]
pub struct PatchApiKeyRequest {
    pub name: String,
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

    let keys = sqlx::query_as::<_, ApiKey>(
        "SELECT id, user_id, name, key, last_used, created_at FROM api_keys WHERE user_id = $1 ORDER BY created_at DESC"
    )
    .bind(user_id)
    .fetch_all(pool.get_ref())
    .await;

    match keys {
        Ok(rows) => {
            let public: Vec<ApiKeyPublic> = rows.into_iter().map(to_public).collect();
            HttpResponse::Ok().json(public)
        }
        Err(e) => {
            eprintln!("Failed to fetch API keys: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to fetch API keys".into(),
            })
        }
    }
}

pub async fn create(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    payload: web::Json<CreateApiKeyRequest>,
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
    let key = format!("wpk_{}", Uuid::new_v4().as_simple());

    let result = sqlx::query(
        "INSERT INTO api_keys (id, user_id, name, key) VALUES ($1, $2, $3, $4)"
    )
    .bind(id)
    .bind(user_id)
    .bind(&payload.name)
    .bind(&key)
    .execute(pool.get_ref())
    .await;

    match result {
        Ok(_) => HttpResponse::Ok().json(serde_json::json!({
            "id": id.to_string(),
            "key": key,
            "name": payload.name,
        })),
        Err(e) => {
            eprintln!("Failed to create API key: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to create API key".into(),
            })
        }
    }
}

pub async fn patch(
    req: HttpRequest,
    pool: web::Data<PgPool>,
    path: web::Path<Uuid>,
    payload: web::Json<PatchApiKeyRequest>,
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

    let name = payload.name.trim();
    if name.is_empty() || name.len() > 256 {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid name (1–256 chars)".into(),
        });
    }

    let key_id = path.into_inner();
    let row = sqlx::query_as::<_, ApiKey>(
        r#"UPDATE api_keys SET name = $1 WHERE id = $2 AND user_id = $3
           RETURNING id, user_id, name, key, last_used, created_at"#,
    )
    .bind(name)
    .bind(key_id)
    .bind(user_id)
    .fetch_optional(pool.get_ref())
    .await;

    match row {
        Ok(Some(k)) => HttpResponse::Ok().json(to_public(k)),
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "API key not found".into(),
        }),
        Err(e) => {
            eprintln!("Failed to patch API key: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update API key".into(),
            })
        }
    }
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

    let key_id = path.into_inner();

    let result = sqlx::query("DELETE FROM api_keys WHERE id = $1 AND user_id = $2")
        .bind(key_id)
        .bind(user_id)
        .execute(pool.get_ref())
        .await;

    match result {
        Ok(rows) if rows.rows_affected() > 0 => HttpResponse::Ok().json(serde_json::json!({"message": "API key deleted"})),
        Ok(_) => HttpResponse::NotFound().json(ErrorResponse {
            error: "API key not found".into(),
        }),
        Err(e) => {
            eprintln!("Failed to delete API key: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to delete API key".into(),
            })
        }
    }
}