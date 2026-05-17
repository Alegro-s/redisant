
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

use crate::{get_user_id_from_token, ErrorResponse};

pub static NETWORK_DRIVE_PROTOCOLS: &[&str] =
    &["s3", "webdav", "nfs", "smb", "ftp", "timeweb_s3", "custom"];

fn protocol_ok(p: &str) -> bool {
    let x = p.trim().to_lowercase();
    NETWORK_DRIVE_PROTOCOLS.iter().any(|v| *v == x.as_str())
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct NetworkDriveRow {
    pub id: Uuid,
    pub owner_id: Uuid,
    pub name: String,
    pub protocol: String,
    pub endpoint_uri: String,
    pub path_prefix: String,
    pub meta: serde_json::Value,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct CreateNetworkDriveRequest {
    pub name: String,
    pub protocol: String,
    pub endpoint_uri: String,
    #[serde(default)]
    pub path_prefix: String,
    #[serde(default)]
    pub meta: serde_json::Value,
}

#[derive(Debug, Deserialize)]
pub struct PatchNetworkDriveRequest {
    pub name: Option<String>,
    pub protocol: Option<String>,
    pub endpoint_uri: Option<String>,
    pub path_prefix: Option<String>,
    pub meta: Option<serde_json::Value>,
}

pub async fn list(req: HttpRequest, pool: web::Data<sqlx::PgPool>) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(resp) => return resp,
    };
    let rows = sqlx::query_as::<_, NetworkDriveRow>(
        "SELECT id, owner_id, name, protocol, endpoint_uri, path_prefix, meta, created_at, updated_at FROM waypoint_network_drives WHERE owner_id = $1 ORDER BY created_at DESC",
    )
    .bind(uid)
    .fetch_all(pool.get_ref())
    .await;
    match rows {
        Ok(r) => HttpResponse::Ok().json(json!({ "items": r })),
        Err(e) => {
            log::error!("network_drives list: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to list network drives".into(),
            })
        }
    }
}

pub async fn create(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
    body: web::Json<CreateNetworkDriveRequest>,
) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(resp) => return resp,
    };
    let name = body.name.trim();
    if name.is_empty() || name.len() > 128 {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "name must be 1..128 chars".into(),
        });
    }
    if !protocol_ok(&body.protocol) {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: format!(
                "protocol must be one of: {}",
                NETWORK_DRIVE_PROTOCOLS.join(", ")
            ),
        });
    }
    let ep = body.endpoint_uri.trim();
    if ep.is_empty() || ep.len() > 2048 {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "endpoint_uri must be 1..2048 chars".into(),
        });
    }
    let proto = body.protocol.trim().to_lowercase();
    let prefix = body.path_prefix.trim().to_string();
    let id = Uuid::new_v4();
    let res = sqlx::query_as::<_, NetworkDriveRow>(
        r#"INSERT INTO waypoint_network_drives (id, owner_id, name, protocol, endpoint_uri, path_prefix, meta)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           RETURNING id, owner_id, name, protocol, endpoint_uri, path_prefix, meta, created_at, updated_at"#,
    )
    .bind(id)
    .bind(uid)
    .bind(name)
    .bind(&proto)
    .bind(ep)
    .bind(&prefix)
    .bind(&body.meta)
    .fetch_one(pool.get_ref())
    .await;
    match res {
        Ok(row) => HttpResponse::Ok().json(row),
        Err(e) => {
            log::error!("network_drives create: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to create network drive".into(),
            })
        }
    }
}

pub async fn get(req: HttpRequest, pool: web::Data<sqlx::PgPool>, path: web::Path<Uuid>) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(resp) => return resp,
    };
    let id = path.into_inner();
    let row = sqlx::query_as::<_, NetworkDriveRow>(
        "SELECT id, owner_id, name, protocol, endpoint_uri, path_prefix, meta, created_at, updated_at FROM waypoint_network_drives WHERE id = $1 AND owner_id = $2",
    )
    .bind(id)
    .bind(uid)
    .fetch_optional(pool.get_ref())
    .await;
    match row {
        Ok(Some(r)) => HttpResponse::Ok().json(r),
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "Not found".into(),
        }),
        Err(e) => {
            log::error!("network_drives get: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load network drive".into(),
            })
        }
    }
}

pub async fn patch(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
    path: web::Path<Uuid>,
    body: web::Json<PatchNetworkDriveRequest>,
) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(resp) => return resp,
    };
    let id = path.into_inner();
    let cur = sqlx::query_as::<_, NetworkDriveRow>(
        "SELECT id, owner_id, name, protocol, endpoint_uri, path_prefix, meta, created_at, updated_at FROM waypoint_network_drives WHERE id = $1 AND owner_id = $2",
    )
    .bind(id)
    .bind(uid)
    .fetch_optional(pool.get_ref())
    .await;
    let row_opt = match cur {
        Ok(r) => r,
        Err(e) => {
            log::error!("network_drives patch load: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load network drive".into(),
            });
        }
    };
    let Some(mut row) = row_opt else {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "Not found".into(),
        });
    };

    if let Some(ref name) = body.name {
        let n = name.trim();
        if n.is_empty() || n.len() > 128 {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "name must be 1..128 chars".into(),
            });
        }
        row.name = n.to_string();
    }
    if let Some(ref p) = body.protocol {
        if !protocol_ok(p) {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: format!(
                    "protocol must be one of: {}",
                    NETWORK_DRIVE_PROTOCOLS.join(", ")
                ),
            });
        }
        row.protocol = p.trim().to_lowercase();
    }
    if let Some(ref ep) = body.endpoint_uri {
        let e = ep.trim();
        if e.is_empty() || e.len() > 2048 {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "endpoint_uri must be 1..2048 chars".into(),
            });
        }
        row.endpoint_uri = e.to_string();
    }
    if let Some(ref pp) = body.path_prefix {
        row.path_prefix = pp.trim().to_string();
    }
    if let Some(ref m) = body.meta {
        row.meta = m.clone();
    }

    let updated = sqlx::query_as::<_, NetworkDriveRow>(
        r#"UPDATE waypoint_network_drives SET name = $1, protocol = $2, endpoint_uri = $3, path_prefix = $4, meta = $5, updated_at = now()
           WHERE id = $6 AND owner_id = $7
           RETURNING id, owner_id, name, protocol, endpoint_uri, path_prefix, meta, created_at, updated_at"#,
    )
    .bind(&row.name)
    .bind(&row.protocol)
    .bind(&row.endpoint_uri)
    .bind(&row.path_prefix)
    .bind(&row.meta)
    .bind(id)
    .bind(uid)
    .fetch_optional(pool.get_ref())
    .await;

    match updated {
        Ok(Some(r)) => HttpResponse::Ok().json(r),
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "Not found".into(),
        }),
        Err(e) => {
            log::error!("network_drives patch: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update network drive".into(),
            })
        }
    }
}

fn auth_uid(req: &HttpRequest) -> Result<Uuid, HttpResponse> {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return Err(HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            }));
        }
    };
    match get_user_id_from_token(req, &jwt_secret) {
        Some(id) => Ok(id),
        None => Err(HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        })),
    }
}

pub async fn delete(req: HttpRequest, pool: web::Data<sqlx::PgPool>, path: web::Path<Uuid>) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(resp) => return resp,
    };
    let id = path.into_inner();
    let res = sqlx::query("DELETE FROM waypoint_network_drives WHERE id = $1 AND owner_id = $2")
        .bind(id)
        .bind(uid)
        .execute(pool.get_ref())
        .await;
    match res {
        Ok(r) if r.rows_affected() > 0 => HttpResponse::Ok().json(json!({ "ok": true })),
        Ok(_) => HttpResponse::NotFound().json(ErrorResponse {
            error: "Not found".into(),
        }),
        Err(e) => {
            log::error!("network_drives delete: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to delete network drive".into(),
            })
        }
    }
}
