
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

use crate::{access, get_user_id_from_token, AppState, ErrorResponse};

#[derive(Serialize, sqlx::FromRow)]
struct SceneRowMeta {
    scene_id: String,
    revision: i64,
    updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Serialize)]
struct SceneBodyResponse {
    scene_id: String,
    revision: i64,
    updated_at: chrono::DateTime<chrono::Utc>,
    content: Value,
}

#[derive(Deserialize)]
pub(crate) struct ScenePutBody {
    content: Value,
    base_revision: i64,
}

fn jwt_secret() -> Result<String, HttpResponse> {
    std::env::var("JWT_SECRET").map_err(|_| {
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        })
    })
}

async fn auth_user(req: &HttpRequest) -> Result<Uuid, HttpResponse> {
    let secret = jwt_secret()?;
    let uid = get_user_id_from_token(req, &secret).ok_or_else(|| {
        HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        })
    })?;
    Ok(uid)
}

pub async fn list_project_scenes(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    let project_id = path.into_inner();
    let uid = match auth_user(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    if !access::user_can_read_project(&state.pool, Some(uid), project_id)
        .await
        .unwrap_or(false)
    {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }
    let rows: Vec<SceneRowMeta> =
        sqlx::query_as("SELECT scene_id, revision, updated_at FROM project_scenes WHERE project_id = $1 ORDER BY scene_id")
            .bind(project_id)
            .fetch_all(&state.pool)
            .await
            .unwrap_or_default();
    HttpResponse::Ok().json(rows)
}

pub async fn get_project_scene(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<(Uuid, String)>,
) -> impl Responder {
    let (project_id, scene_id) = path.into_inner();
    let uid = match auth_user(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    if !access::user_can_read_project(&state.pool, Some(uid), project_id)
        .await
        .unwrap_or(false)
    {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }
    let row: Option<(Value, i64, chrono::DateTime<chrono::Utc>)> = sqlx::query_as(
        "SELECT content, revision, updated_at FROM project_scenes WHERE project_id = $1 AND scene_id = $2",
    )
    .bind(project_id)
    .bind(&scene_id)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    match row {
        Some((content, revision, updated_at)) => HttpResponse::Ok().json(SceneBodyResponse {
            scene_id,
            revision,
            updated_at,
            content,
        }),
        None => HttpResponse::NotFound().json(ErrorResponse {
            error: "Scene not found".into(),
        }),
    }
}

pub async fn put_project_scene(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<(Uuid, String)>,
    body: web::Json<ScenePutBody>,
) -> impl Responder {
    let (project_id, scene_id) = path.into_inner();
    let body = body.into_inner();
    let uid = match auth_user(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    if !access::user_can_write_project(&state.pool, uid, project_id)
        .await
        .unwrap_or(false)
    {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Write access denied (owner or editor)".into(),
        });
    }

    let mut tx = match state.pool.begin().await {
        Ok(t) => t,
        Err(e) => {
            log::error!("scene tx: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            });
        }
    };

    let current: Option<(i64,)> =
        sqlx::query_as("SELECT revision FROM project_scenes WHERE project_id = $1 AND scene_id = $2 FOR UPDATE")
            .bind(project_id)
            .bind(&scene_id)
            .fetch_optional(&mut *tx)
            .await
            .unwrap_or(None);

    match current {
        None => {
            if body.base_revision != 0 {
                let _ = tx.rollback().await;
                return HttpResponse::Conflict().json(ErrorResponse {
                    error: "Scene exists on server or wrong base_revision; use 0 for new".into(),
                });
            }
            if let Err(e) = sqlx::query(
                r#"INSERT INTO project_scenes (project_id, scene_id, content, revision, updated_by)
                   VALUES ($1, $2, $3, 1, $4)"#,
            )
            .bind(project_id)
            .bind(&scene_id)
            .bind(&body.content)
            .bind(uid)
            .execute(&mut *tx)
            .await
            {
                if let Some(db) = e.as_database_error() {
                    if db.code().as_deref() == Some("23505") {
                        let _ = tx.rollback().await;
                        return HttpResponse::Conflict().json(ErrorResponse {
                            error: "scene already exists; refresh and retry with current revision"
                                .into(),
                        });
                    }
                }
                log::error!("scene insert: {}", e);
                let _ = tx.rollback().await;
                return HttpResponse::InternalServerError().json(ErrorResponse {
                    error: "database error".into(),
                });
            }
        }
        Some((rev,)) => {
            if rev != body.base_revision {
                let _ = tx.rollback().await;
                return HttpResponse::Conflict().json(serde_json::json!({
                    "error": "revision conflict",
                    "current_revision": rev,
                }));
            }
            if let Err(e) = sqlx::query(
                r#"UPDATE project_scenes SET content = $1, revision = revision + 1, updated_at = now(), updated_by = $2
                   WHERE project_id = $3 AND scene_id = $4"#,
            )
            .bind(&body.content)
            .bind(uid)
            .bind(project_id)
            .bind(&scene_id)
            .execute(&mut *tx)
            .await
            {
                log::error!("scene update: {}", e);
                let _ = tx.rollback().await;
                return HttpResponse::InternalServerError().json(ErrorResponse {
                    error: "database error".into(),
                });
            }
        }
    }

    if let Err(e) = tx.commit().await {
        log::error!("scene commit: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "database error".into(),
        });
    }

    let row: Option<(Value, i64, chrono::DateTime<chrono::Utc>)> = sqlx::query_as(
        "SELECT content, revision, updated_at FROM project_scenes WHERE project_id = $1 AND scene_id = $2",
    )
    .bind(project_id)
    .bind(&scene_id)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    match row {
        Some((content, revision, updated_at)) => HttpResponse::Ok().json(SceneBodyResponse {
            scene_id,
            revision,
            updated_at,
            content,
        }),
        None => HttpResponse::InternalServerError().json(ErrorResponse {
            error: "persist failed".into(),
        }),
    }
}
