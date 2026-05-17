
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

async fn ensure_project_owner(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    owner_id: Uuid,
) -> Result<(), HttpResponse> {
    let ok: Option<(Uuid,)> = sqlx::query_as(
        r#"SELECT id FROM nexus_cloud_projects WHERE id = $1 AND owner_id = $2"#,
    )
    .bind(project_id)
    .bind(owner_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| {
        log::error!("nexus_cloud_builds project check: {}", e);
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "database error".into(),
        })
    })?;
    if ok.is_none() {
        return Err(HttpResponse::NotFound().json(ErrorResponse {
            error: "project not found".into(),
        }));
    }
    Ok(())
}

#[derive(Serialize, sqlx::FromRow)]
pub struct BuildJobRow {
    pub id: Uuid,
    pub project_id: Uuid,
    pub owner_id: Uuid,
    pub status: String,
    pub ref_name: Option<String>,
    pub label: Option<String>,
    pub log_excerpt: Option<String>,
    pub meta: serde_json::Value,
    pub bullmq_job_id: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub started_at: Option<chrono::DateTime<chrono::Utc>>,
    pub finished_at: Option<chrono::DateTime<chrono::Utc>>,
    pub error_message: Option<String>,
}

#[derive(Deserialize)]
pub struct CreateBuildBody {
    pub ref_name: Option<String>,
    pub label: Option<String>,
}

pub async fn create_build(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
    body: web::Json<CreateBuildBody>,
) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let project_id = path.into_inner();
    if let Err(e) = ensure_project_owner(&state.pool, project_id, uid).await {
        return e;
    }

    let ref_name = body
        .ref_name
        .as_ref()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty() && s.len() <= 512);
    let label = body
        .label
        .as_ref()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty() && s.len() <= 512);

    let row: Result<BuildJobRow, _> = sqlx::query_as(
        r#"INSERT INTO nexus_cloud_build_jobs (project_id, owner_id, status, ref_name, label)
           VALUES ($1, $2, 'queued', $3, $4)
           RETURNING id, project_id, owner_id, status, ref_name, label, log_excerpt, meta,
                     bullmq_job_id, created_at, started_at, finished_at, error_message"#,
    )
    .bind(project_id)
    .bind(uid)
    .bind(ref_name.as_ref())
    .bind(label.as_ref())
    .fetch_one(&state.pool)
    .await;

    let job = match row {
        Ok(j) => j,
        Err(e) => {
            log::error!("nexus_cloud_builds insert: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "could not create build".into(),
            });
        }
    };

    let payload = json!({
        "build_job_id": job.id.to_string(),
        "project_id": project_id.to_string(),
        "owner_id": uid.to_string(),
    })
    .to_string();

    if let Some(mut redis) = state.redis.clone() {
        let push: Result<(), redis::RedisError> = redis::cmd("RPUSH")
            .arg("nexus-cloud-simple-build-queue")
            .arg(&payload)
            .query_async(&mut redis)
            .await;
        if let Err(e) = push {
            log::warn!("nexus_cloud_builds redis rpush: {}", e);
        }
    }

    HttpResponse::Ok().json(&job)
}

pub async fn list_project_builds(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let project_id = path.into_inner();
    if let Err(e) = ensure_project_owner(&state.pool, project_id, uid).await {
        return e;
    }

    let rows: Result<Vec<BuildJobRow>, _> = sqlx::query_as(
        r#"SELECT id, project_id, owner_id, status, ref_name, label, log_excerpt, meta,
                  bullmq_job_id, created_at, started_at, finished_at, error_message
           FROM nexus_cloud_build_jobs
           WHERE project_id = $1
           ORDER BY created_at DESC
           LIMIT 100"#,
    )
    .bind(project_id)
    .fetch_all(&state.pool)
    .await;

    match rows {
        Ok(list) => HttpResponse::Ok().json(json!({ "builds": list })),
        Err(e) => {
            log::error!("nexus_cloud_builds list: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}

pub async fn list_my_builds(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };

    let rows: Result<Vec<BuildJobRow>, _> = sqlx::query_as(
        r#"SELECT id, project_id, owner_id, status, ref_name, label, log_excerpt, meta,
                  bullmq_job_id, created_at, started_at, finished_at, error_message
           FROM nexus_cloud_build_jobs
           WHERE owner_id = $1
           ORDER BY created_at DESC
           LIMIT 200"#,
    )
    .bind(uid)
    .fetch_all(&state.pool)
    .await;

    match rows {
        Ok(list) => HttpResponse::Ok().json(json!({ "builds": list })),
        Err(e) => {
            log::error!("nexus_cloud_builds list_my: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}

#[derive(Deserialize)]
pub struct WorkerReportBody {
    pub build_job_id: Uuid,
    pub status: String,
    pub log_excerpt: Option<String>,
    pub error_message: Option<String>,
}

pub async fn worker_build_report(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<WorkerReportBody>,
) -> impl Responder {
    let expected = match env::var("LYNX_BUILD_WORKER_SECRET")
        .ok()
        .filter(|s| !s.is_empty())
        .or_else(|| env::var("NEXUS_BUILD_WORKER_SECRET").ok().filter(|s| !s.is_empty()))
    {
        Some(s) => s,
        None => {
            return HttpResponse::ServiceUnavailable().json(ErrorResponse {
                error: "LYNX_BUILD_WORKER_SECRET or NEXUS_BUILD_WORKER_SECRET not configured".into(),
            });
        }
    };
    let got = req
        .headers()
        .get("X-Lynx-Build-Worker-Secret")
        .or_else(|| req.headers().get("X-Nexus-Build-Worker-Secret"))
        .and_then(|h| h.to_str().ok())
        .unwrap_or("");
    if got != expected {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "invalid worker secret".into(),
        });
    }

    let st = body.status.to_lowercase();
    if !matches!(st.as_str(), "running" | "succeeded" | "failed" | "cancelled") {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "status must be running|succeeded|failed|cancelled".into(),
        });
    }

    let now = chrono::Utc::now();
    let terminal = matches!(st.as_str(), "succeeded" | "failed" | "cancelled");

    let row: Result<Option<BuildJobRow>, _> = sqlx::query_as(
        r#"UPDATE nexus_cloud_build_jobs SET
             status = $1,
             log_excerpt = COALESCE($3, log_excerpt),
             error_message = COALESCE($4, error_message),
             started_at = CASE
               WHEN $1 = 'running' AND started_at IS NULL THEN $5
               ELSE started_at
             END,
             finished_at = CASE
               WHEN $6 THEN $5
               ELSE finished_at
             END
           WHERE id = $2
           RETURNING id, project_id, owner_id, status, ref_name, label, log_excerpt, meta,
                     bullmq_job_id, created_at, started_at, finished_at, error_message"#,
    )
    .bind(&st)
    .bind(body.build_job_id)
    .bind(body.log_excerpt.as_ref())
    .bind(body.error_message.as_ref())
    .bind(now)
    .bind(terminal)
    .fetch_optional(&state.pool)
    .await;

    match row {
        Ok(Some(j)) => HttpResponse::Ok().json(j),
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "build job not found".into(),
        }),
        Err(e) => {
            log::error!("nexus_cloud_builds worker_report: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}
