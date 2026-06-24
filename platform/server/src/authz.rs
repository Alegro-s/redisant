use actix_web::{HttpRequest, HttpResponse};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{get_user_id_from_token, is_admin, is_nexus, ErrorResponse};

fn lynx_ops_emails() -> Vec<String> {
    std::env::var("LYNX_OPS_EMAILS")
        .ok()
        .unwrap_or_else(|| "rozalityai@gmail.com".into())
        .split(',')
        .map(|s| s.trim().to_lowercase())
        .filter(|s| !s.is_empty())
        .collect()
}

pub async fn is_lynx_ops(pool: &PgPool, user_id: Uuid) -> bool {
    if is_nexus(pool, user_id).await || is_admin(pool, user_id).await {
        return true;
    }
    let ops = lynx_ops_emails();
    if ops.is_empty() {
        return false;
    }
    let email: Option<String> = sqlx::query_scalar(
        "SELECT lower(trim(email)) FROM users WHERE id = $1",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .unwrap_or(None);
    email.map(|e| ops.contains(&e)).unwrap_or(false)
}

pub async fn require_lynx_ops(pool: &PgPool, req: &HttpRequest) -> Result<Uuid, HttpResponse> {
    let secret = jwt_secret_or_500()?;
    let uid = get_user_id_from_token(req, &secret).ok_or_else(|| {
        HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        })
    })?;
    if !is_lynx_ops(pool, uid).await {
        return Err(HttpResponse::Forbidden().json(ErrorResponse {
            error: "Требуется роль NEXUS или ops-доступ.".into(),
        }));
    }
    Ok(uid)
}

fn jwt_secret_or_500() -> Result<String, HttpResponse> {
    std::env::var("JWT_SECRET").map_err(|_| {
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        })
    })
}

pub async fn require_staff(pool: &PgPool, req: &HttpRequest) -> Result<Uuid, HttpResponse> {
    let secret = jwt_secret_or_500()?;
    let uid = get_user_id_from_token(req, &secret).ok_or_else(|| {
        HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        })
    })?;
    if !is_admin(pool, uid).await {
        return Err(HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        }));
    }
    Ok(uid)
}

pub async fn require_nexus(pool: &PgPool, req: &HttpRequest) -> Result<Uuid, HttpResponse> {
    let secret = jwt_secret_or_500()?;
    let uid = get_user_id_from_token(req, &secret).ok_or_else(|| {
        HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        })
    })?;
    if !is_nexus(pool, uid).await {
        return Err(HttpResponse::Forbidden().json(ErrorResponse {
            error: "Требуется роль NEXUS (команда платформы).".into(),
        }));
    }
    Ok(uid)
}
