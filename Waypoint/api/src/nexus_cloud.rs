
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::env;
use uuid::Uuid;

use crate::{get_user_id_from_token, AppState, ErrorResponse};

fn jwt_secret() -> Result<String, HttpResponse> {
    env::var("JWT_SECRET").map_err(|_| {
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        })
    })
}

fn auth_uid(req: &HttpRequest) -> Result<Uuid, HttpResponse> {
    let secret = jwt_secret()?;
    get_user_id_from_token(req, &secret).ok_or_else(|| {
        HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        })
    })
}

#[derive(Serialize, sqlx::FromRow)]
struct CloudProject {
    id: Uuid,
    name: String,
    description: Option<String>,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

pub async fn list_projects(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let rows: Result<Vec<CloudProject>, _> = sqlx::query_as(
        r#"SELECT id, name, description, created_at, updated_at
           FROM nexus_cloud_projects WHERE owner_id = $1 ORDER BY created_at DESC"#,
    )
    .bind(uid)
    .fetch_all(&state.pool)
    .await;
    match rows {
        Ok(list) => HttpResponse::Ok().json(json!({ "projects": list })),
        Err(e) => {
            log::error!("nexus_cloud list: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}

#[derive(Deserialize)]
pub struct CreateCloudProject {
    name: String,
    description: Option<String>,
}

pub async fn create_project(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<CreateCloudProject>,
) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let name = body.name.trim();
    if name.is_empty() || name.len() > 200 {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid name".into(),
        });
    }
    let row: Result<CloudProject, _> = sqlx::query_as(
        r#"INSERT INTO nexus_cloud_projects (owner_id, name, description)
           VALUES ($1, $2, $3)
           RETURNING id, name, description, created_at, updated_at"#,
    )
    .bind(uid)
    .bind(name)
    .bind(body.description.as_ref())
    .fetch_one(&state.pool)
    .await;
    match row {
        Ok(p) => HttpResponse::Ok().json(p),
        Err(e) => {
            log::error!("nexus_cloud create: {}", e);
            HttpResponse::BadRequest().json(ErrorResponse {
                error: "could not create project".into(),
            })
        }
    }
}

pub async fn get_project(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let id = path.into_inner();
    let row: Result<Option<CloudProject>, _> = sqlx::query_as(
        r#"SELECT id, name, description, created_at, updated_at
           FROM nexus_cloud_projects WHERE id = $1 AND owner_id = $2"#,
    )
    .bind(id)
    .bind(uid)
    .fetch_optional(&state.pool)
    .await;
    match row {
        Ok(Some(p)) => HttpResponse::Ok().json(p),
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "not found".into(),
        }),
        Err(e) => {
            log::error!("nexus_cloud get: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}

#[derive(Deserialize)]
pub struct PatchCloudProject {
    name: Option<String>,
    description: Option<String>,
}

pub async fn patch_project(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
    body: web::Json<PatchCloudProject>,
) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let id = path.into_inner();
    if body.name.is_none() && body.description.is_none() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "nothing to update".into(),
        });
    }
    let name = body
        .name
        .as_ref()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty() && s.len() <= 200);
    let row: Result<Option<CloudProject>, _> = sqlx::query_as(
        r#"UPDATE nexus_cloud_projects SET
             name = COALESCE($3, name),
             description = COALESCE($4, description),
             updated_at = now()
           WHERE id = $1 AND owner_id = $2
           RETURNING id, name, description, created_at, updated_at"#,
    )
    .bind(id)
    .bind(uid)
    .bind(name.as_ref())
    .bind(body.description.as_ref())
    .fetch_optional(&state.pool)
    .await;
    match row {
        Ok(Some(p)) => HttpResponse::Ok().json(p),
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "not found".into(),
        }),
        Err(e) => {
            log::error!("nexus_cloud patch: {}", e);
            HttpResponse::BadRequest().json(ErrorResponse {
                error: "update failed".into(),
            })
        }
    }
}

pub async fn delete_project(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let id = path.into_inner();
    let r = sqlx::query("DELETE FROM nexus_cloud_projects WHERE id = $1 AND owner_id = $2")
        .bind(id)
        .bind(uid)
        .execute(&state.pool)
        .await;
    match r {
        Ok(x) if x.rows_affected() > 0 => HttpResponse::Ok().json(json!({ "ok": true })),
        Ok(_) => HttpResponse::NotFound().json(ErrorResponse {
            error: "not found".into(),
        }),
        Err(e) => {
            log::error!("nexus_cloud delete: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}
