
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

pub async fn record_asset_download(
    pool: &sqlx::PgPool,
    asset_kind: &str,
    asset_id: &str,
    user_id: Option<Uuid>,
) {
    if let Err(e) = sqlx::query(
        "INSERT INTO lynx_asset_downloads (asset_kind, asset_id, user_id) VALUES ($1, $2, $3)",
    )
    .bind(asset_kind)
    .bind(asset_id)
    .bind(user_id)
    .execute(pool)
    .await
    {
        log::warn!("lynx_asset_downloads insert: {}", e);
    }
}

#[derive(Serialize)]
pub struct LynxCloudOverview {
    pub projects: i64,
    pub builds: i64,
    pub downloads_30d: i64,
    pub sessions_30d: i64,
    pub revenue_rub: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ingest_api_key: Option<String>,
}

pub async fn get_overview(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };

    let projects: i64 = sqlx::query_scalar(
        "SELECT COUNT(*)::bigint FROM nexus_cloud_projects WHERE owner_id = $1",
    )
    .bind(uid)
    .fetch_one(&state.pool)
    .await
    .unwrap_or(0);

    let builds: i64 = sqlx::query_scalar(
        r#"SELECT COUNT(*)::bigint FROM nexus_cloud_builds WHERE owner_id = $1"#,
    )
    .bind(uid)
    .fetch_one(&state.pool)
    .await
    .unwrap_or(0);

    let downloads_30d: i64 = sqlx::query_scalar(
        r#"SELECT COUNT(*)::bigint FROM lynx_asset_downloads
           WHERE user_id = $1 AND created_at > NOW() - INTERVAL '30 days'"#,
    )
    .bind(uid)
    .fetch_one(&state.pool)
    .await
    .unwrap_or(0);

    let sessions_30d: i64 = sqlx::query_scalar(
        r#"SELECT COALESCE(SUM(duration_sec), 0)::bigint FROM lynx_play_sessions
           WHERE user_id = $1 AND created_at > NOW() - INTERVAL '30 days'"#,
    )
    .bind(uid)
    .fetch_one(&state.pool)
    .await
    .unwrap_or(0);

    let balance_cents: i32 = sqlx::query_scalar(
        "SELECT balance_cents FROM billing_accounts WHERE user_id = $1",
    )
    .bind(uid)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None)
    .unwrap_or(0);

    let ingest = crate::platform::ensure_default_ingest_key(&state.pool, uid).await;

    HttpResponse::Ok().json(LynxCloudOverview {
        projects,
        builds,
        downloads_30d,
        sessions_30d,
        revenue_rub: balance_cents as f64 / 100.0,
        ingest_api_key: ingest,
    })
}

#[derive(Serialize)]
pub struct LynxAnalyticsDay {
    pub date: String,
    pub downloads: i64,
    pub sessions: i64,
}

pub async fn get_analytics(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };

    let downloads: Vec<(chrono::NaiveDate, i64)> = sqlx::query_as(
        r#"SELECT DATE(created_at) AS d, COUNT(*)::bigint
           FROM lynx_asset_downloads
           WHERE user_id = $1 AND created_at > NOW() - INTERVAL '30 days'
           GROUP BY DATE(created_at)
           ORDER BY d"#,
    )
    .bind(uid)
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    let sessions: Vec<(chrono::NaiveDate, i64)> = sqlx::query_as(
        r#"SELECT DATE(created_at) AS d, COALESCE(SUM(duration_sec), 0)::bigint
           FROM lynx_play_sessions
           WHERE user_id = $1 AND created_at > NOW() - INTERVAL '30 days'
           GROUP BY DATE(created_at)
           ORDER BY d"#,
    )
    .bind(uid)
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    use std::collections::BTreeMap;
    let mut map: BTreeMap<String, LynxAnalyticsDay> = BTreeMap::new();
    for (d, c) in downloads {
        let key = d.format("%Y-%m-%d").to_string();
        map.entry(key.clone())
            .or_insert(LynxAnalyticsDay {
                date: key,
                downloads: 0,
                sessions: 0,
            })
            .downloads = c;
    }
    for (d, c) in sessions {
        let key = d.format("%Y-%m-%d").to_string();
        map.entry(key.clone())
            .or_insert(LynxAnalyticsDay {
                date: key,
                downloads: 0,
                sessions: 0,
            })
            .sessions = c;
    }

    HttpResponse::Ok().json(json!({
        "range": "30d",
        "days": map.into_values().collect::<Vec<_>>(),
    }))
}

#[derive(Deserialize)]
pub struct TelemetryBody {
    pub project_id: Option<Uuid>,
    pub duration_sec: Option<i32>,
}

pub async fn post_telemetry(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<TelemetryBody>,
) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let dur = body.duration_sec.unwrap_or(0).max(0).min(86400);
    if let Some(pid) = body.project_id {
        let owned: Option<Uuid> = sqlx::query_scalar(
            "SELECT id FROM nexus_cloud_projects WHERE id = $1 AND owner_id = $2",
        )
        .bind(pid)
        .bind(uid)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None);
        if owned.is_none() {
            return HttpResponse::NotFound().json(ErrorResponse {
                error: "project not found".into(),
            });
        }
        if let Err(e) = sqlx::query(
            "INSERT INTO lynx_play_sessions (project_id, user_id, duration_sec) VALUES ($1, $2, $3)",
        )
        .bind(pid)
        .bind(uid)
        .bind(dur)
        .execute(&state.pool)
        .await
        {
            log::error!("lynx_play_sessions: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            });
        }
    }
    HttpResponse::Ok().json(json!({ "ok": true }))
}
