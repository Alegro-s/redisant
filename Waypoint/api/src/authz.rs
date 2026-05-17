use actix_web::{HttpRequest, HttpResponse};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{get_user_id_from_token, is_admin, is_nexus, ErrorResponse};

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
