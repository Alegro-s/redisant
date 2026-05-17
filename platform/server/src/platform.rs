
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

use crate::blocking;
use crate::{get_user_id_from_token, is_admin, AppState, ErrorResponse};

fn jwt_secret() -> Result<String, HttpResponse> {
    std::env::var("JWT_SECRET").map_err(|_| {
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        })
    })
}

async fn auth_uid(req: &HttpRequest) -> Result<Uuid, HttpResponse> {
    let secret = jwt_secret()?;
    get_user_id_from_token(req, &secret).ok_or_else(|| {
        HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        })
    })
}

async fn ensure_default_ingest_key(pool: &sqlx::PgPool, user_id: Uuid) -> Option<String> {
    let existing: Option<String> = sqlx::query_scalar(
        "SELECT key FROM api_keys WHERE user_id = $1 AND name = 'default' ORDER BY created_at ASC LIMIT 1",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .unwrap_or(None);
    if let Some(k) = existing {
        return Some(k);
    }
    let key_id = Uuid::new_v4();
    let api_key = format!("nx_{}", Uuid::new_v4().as_simple());
    match sqlx::query(
        "INSERT INTO api_keys (id, user_id, name, key) VALUES ($1, $2, 'default', $3)",
    )
    .bind(key_id)
    .bind(user_id)
    .bind(&api_key)
    .execute(pool)
    .await
    {
        Ok(_) => Some(api_key),
        Err(e) => {
            log::warn!("ensure_default_ingest_key insert: {}", e);
            sqlx::query_scalar(
                "SELECT key FROM api_keys WHERE user_id = $1 AND name = 'default' ORDER BY created_at ASC LIMIT 1",
            )
            .bind(user_id)
            .fetch_optional(pool)
            .await
            .unwrap_or(None)
        }
    }
}

#[derive(Serialize, sqlx::FromRow)]
struct WorkspaceRow {
    db_mode: Option<String>,
    agent_api_key: Option<String>,
    connection_url: Option<String>,
    server_hosting: bool,
    onboarding_completed: bool,
    agent_schema_snapshot: Option<serde_json::Value>,
    agent_last_seen: Option<chrono::DateTime<chrono::Utc>>,
}

fn capabilities_for(plan: &str, is_admin_user: bool) -> serde_json::Value {
    let (mut git_gb, mut storage_gb, mut vcpu, mut realtime, mut max_server_rent) = match plan {
        "pro" => (50, 100, 4, true, 3),
        _ => (10, 10, 1, false, 1),
    };
    if is_admin_user {
        git_gb *= 2;
        storage_gb *= 2;
        vcpu = std::cmp::max(vcpu, 4);
        realtime = true;
        max_server_rent += 2;
    }
    json!({
        "git_gb": git_gb,
        "storage_gb": storage_gb,
        "vcpu": vcpu,
        "realtime": realtime,
        "max_server_rent": max_server_rent
    })
}

pub async fn get_workspace(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let row: Option<WorkspaceRow> = sqlx::query_as(
        r#"SELECT db_mode, agent_api_key, connection_url, server_hosting, onboarding_completed,
                  agent_schema_snapshot, agent_last_seen
           FROM user_workspace WHERE user_id = $1"#,
    )
    .bind(uid)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    let ingest = ensure_default_ingest_key(&state.pool, uid).await;
    let is_admin_user = is_admin(&state.pool, uid).await;

    match row {
        Some(w) => HttpResponse::Ok().json(json!({
            "plan": if w.server_hosting { "pro" } else { "basic" },
            "db_mode": w.db_mode,
            "agent_api_key": w.agent_api_key,
            "connection_url": w.connection_url,
            "server_hosting": w.server_hosting,
            "onboarding_completed": w.onboarding_completed,
            "agent_schema_snapshot": w.agent_schema_snapshot,
            "agent_last_seen": w.agent_last_seen,
            "ingest_api_key": ingest,
            "capabilities": capabilities_for(if w.server_hosting { "pro" } else { "basic" }, is_admin_user),
        })),
        None => HttpResponse::Ok().json(json!({
            "plan": "basic",
            "db_mode": null,
            "agent_api_key": null,
            "connection_url": null,
            "server_hosting": false,
            "onboarding_completed": false,
            "agent_schema_snapshot": null,
            "agent_last_seen": null,
            "ingest_api_key": ingest,
            "capabilities": capabilities_for("basic", is_admin_user),
        })),
    }
}

#[derive(Deserialize)]
pub struct WorkspacePutBody {
    pub db_mode: Option<String>,
    pub connection_url: Option<String>,
    pub server_hosting: Option<bool>,
    pub onboarding_completed: Option<bool>,
    pub plan: Option<String>,
}

pub async fn put_workspace(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<WorkspacePutBody>,
) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let b = body.into_inner();

    if let Some(ref m) = b.db_mode {
        if !matches!(m.as_str(), "cloud" | "existing" | "none") {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "db_mode must be cloud, existing, or none".into(),
            });
        }
    }
    if let Some(ref p) = b.plan {
        if !matches!(p.as_str(), "basic" | "pro") {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "plan must be basic or pro".into(),
            });
        }
    }

    let existing: Option<(Option<String>, Option<String>, Option<String>, bool, bool)> =
        sqlx::query_as(
            r#"SELECT db_mode, agent_api_key, connection_url, server_hosting, onboarding_completed
               FROM user_workspace WHERE user_id = $1"#,
        )
        .bind(uid)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None);

    let (em, ea, ec, esh, eo) = existing.unwrap_or((None, None, None, false, false));
    let new_mode = b.db_mode.clone().or(em);
    let mut new_agent = ea;
    let want_agent_key = matches!(new_mode.as_deref(), Some("cloud") | Some("existing"));
    if want_agent_key && new_agent.is_none() {
        new_agent = Some(format!("nx_{}", uuid::Uuid::new_v4().as_simple()));
    }
    let new_conn = match &b.connection_url {
        None => ec,
        Some(s) if s.trim().is_empty() => ec,
        Some(s) => Some(s.trim().to_string()),
    };
    let hosting_by_plan = matches!(b.plan.as_deref(), Some("pro"));
    let new_hosting = b.server_hosting.unwrap_or(esh || hosting_by_plan);
    let new_onb = b.onboarding_completed.unwrap_or(eo);
    let mode_str = new_mode.as_deref().unwrap_or("none");

    let r = sqlx::query(
        r#"INSERT INTO user_workspace
           (user_id, db_mode, agent_api_key, connection_url, server_hosting, onboarding_completed, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, now())
           ON CONFLICT (user_id) DO UPDATE SET
             db_mode = EXCLUDED.db_mode,
             agent_api_key = EXCLUDED.agent_api_key,
             connection_url = EXCLUDED.connection_url,
             server_hosting = EXCLUDED.server_hosting,
             onboarding_completed = EXCLUDED.onboarding_completed,
             updated_at = now()"#,
    )
    .bind(uid)
    .bind(mode_str)
    .bind(&new_agent)
    .bind(&new_conn)
    .bind(new_hosting)
    .bind(new_onb)
    .execute(&state.pool)
    .await;

    match r {
        Ok(_) => {
            let _ = ensure_default_ingest_key(&state.pool, uid).await;
            HttpResponse::Ok().json(json!({ "ok": true }))
        }
        Err(e) => {
            log::error!("put_workspace: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to save workspace".into(),
            })
        }
    }
}

/// Реальный ingest из консоли Metric (сессия JWT, без X-API-Key в браузере).
pub async fn ingest_submit(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<crate::waypoint::ingest_payload::IngestPayload>,
) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let _ = ensure_default_ingest_key(&state.pool, uid).await;
    let key_row = sqlx::query_as::<_, (Uuid,)>(
        "SELECT id FROM api_keys WHERE user_id = $1 ORDER BY created_at ASC LIMIT 1",
    )
    .bind(uid)
    .fetch_optional(&state.pool)
    .await;
    let api_key_id = match key_row {
        Ok(Some((id,))) => id,
        Ok(None) => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "Нет API-ключа. Откройте Ingest Lab → Ключи и выпустите ключ.".into(),
            })
        }
        Err(e) => {
            log::error!("ingest_submit key lookup: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };
    crate::waypoint::ingest::apply_ingest(state.get_ref(), api_key_id, uid, body.into_inner()).await
}

pub async fn ingest_self_test(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let Some(key_id) = sqlx::query_scalar::<_, Uuid>(
        "SELECT id FROM api_keys WHERE user_id = $1 AND name = 'default' ORDER BY created_at ASC LIMIT 1",
    )
    .bind(uid)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None) else {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "No default API key; save workspace once or contact support".into(),
        });
    };
    let ins = sqlx::query(
        r#"INSERT INTO ingested_metrics (api_key_id, name, value, tags, timestamp)
           VALUES ($1, $2, $3, $4, now())"#,
    )
    .bind(key_id)
    .bind("platform.selftest")
    .bind(1.0_f64)
    .bind(json!({"source": "developer_hub"}))
    .execute(&state.pool)
    .await;
    match ins {
        Ok(_) => HttpResponse::Ok().json(json!({
            "ok": true,
            "metric": "platform.selftest",
            "hint": "Проверьте сводку метрик в Ingest Lab или /me/metrics/summary"
        })),
        Err(e) => {
            log::error!("ingest_self_test: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to write metric".into(),
            })
        }
    }
}

#[derive(Deserialize)]
pub struct VkCreateBody {
    pub password: String,
    pub server_ip: String,
    #[serde(default)]
    pub selected_functions: Vec<String>,
}

pub async fn create_vk_module(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<VkCreateBody>,
) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let b = body.into_inner();
    if b.password.len() < 4 {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Password too short".into(),
        });
    }
    let id_token = format!("vk_{}", Uuid::new_v4().as_simple());
    let hash = match blocking::bcrypt_hash_password(&b.password).await {
        Ok(h) => h,
        Err(e) => {
            log::error!("vk hash: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Hash error".into(),
            });
        }
    };
    let funcs = serde_json::to_value(&b.selected_functions).unwrap_or(json!([]));

    let ins = sqlx::query_as::<_, (Uuid,)>(
        r#"INSERT INTO vk_web_module (user_id, id_token, password_hash, server_ip, selected_functions)
           VALUES ($1, $2, $3, $4, $5) RETURNING id"#,
    )
    .bind(uid)
    .bind(&id_token)
    .bind(&hash)
    .bind(b.server_ip.trim())
    .bind(funcs)
    .fetch_one(&state.pool)
    .await;

    match ins {
        Ok((id,)) => HttpResponse::Ok().json(json!({
            "id": id.to_string(),
            "id_token": id_token,
        })),
        Err(e) => {
            log::error!("create_vk_module: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to create VK module".into(),
            })
        }
    }
}

pub async fn list_vk_modules(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let rows: Vec<(Uuid, String, String, serde_json::Value, chrono::DateTime<chrono::Utc>)> =
        sqlx::query_as(
            r#"SELECT id, id_token, server_ip, selected_functions, updated_at
               FROM vk_web_module WHERE user_id = $1 ORDER BY updated_at DESC"#,
        )
        .bind(uid)
        .fetch_all(&state.pool)
        .await
        .unwrap_or_default();

    let out: Vec<serde_json::Value> = rows
        .into_iter()
        .map(|(id, id_token, server_ip, funcs, updated_at)| {
            json!({
                "id": id.to_string(),
                "id_token": id_token,
                "server_ip": server_ip,
                "selected_functions": funcs,
                "updated_at": updated_at,
            })
        })
        .collect();
    HttpResponse::Ok().json(out)
}

#[derive(Deserialize)]
pub struct ModuleTestBody {
    pub label: String,
}

pub async fn create_module_test(
    _state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<ModuleTestBody>,
) -> impl Responder {
    let _auth = match auth_uid(&req).await {
        Ok(uid) => uid,
        Err(e) => return e,
    };
    let ModuleTestBody { label } = body.into_inner();
    if label.trim().is_empty() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "label required".into(),
        });
    }

    HttpResponse::BadRequest().json(ErrorResponse {
        error: "Симуляция отключена. Упакуйте проект в ZIP и запустите прогон через кнопку «Запустить ZIP-тест в runner» в разделе тестирования — в контейнере выполняются ruff, mypy, bandit, pip-audit и pytest (или compileall). На сервере API должен быть доступен Docker (как в docker-compose: сокет docker.sock).".into(),
    })
}

pub async fn list_module_tests(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let rows: Vec<(
        Uuid,
        String,
        Option<String>,
        Option<String>,
        String,
        Option<serde_json::Value>,
        chrono::DateTime<chrono::Utc>,
    )> = sqlx::query_as(
        r#"SELECT id, label, git_url, demo_mode, status, summary, created_at
           FROM module_test_runs WHERE user_id = $1 ORDER BY created_at DESC LIMIT 100"#,
    )
    .bind(uid)
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    let out: Vec<serde_json::Value> = rows
        .into_iter()
        .map(
            |(id, label, git_url, demo_mode, status, summary, created_at)| {
                json!({
                    "id": id.to_string(),
                    "label": label,
                    "git_url": git_url,
                    "demo_mode": demo_mode,
                    "status": status,
                    "summary": summary,
                    "created_at": created_at,
                })
            },
        )
        .collect();
    HttpResponse::Ok().json(out)
}

#[derive(Deserialize)]
pub struct HostingRequestBody {
    pub note: Option<String>,
}

pub async fn request_hosting(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<HostingRequestBody>,
) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let note = body.note.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty());
    if let Err(e) = sqlx::query(
        "INSERT INTO hosting_requests (user_id, note) VALUES ($1, $2)",
    )
    .bind(uid)
    .bind(note)
    .execute(&state.pool)
    .await
    {
        log::error!("request_hosting: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to save request".into(),
        });
    }
    HttpResponse::Ok().json(json!({ "ok": true, "status": "requested" }))
}

pub async fn list_hosting_admin(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match jwt_secret() {
        Ok(s) => s,
        Err(e) => return e,
    };
    let uid = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };
    if !is_admin(&state.pool, uid).await {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let rows: Vec<(
        Uuid,
        Uuid,
        String,
        Option<String>,
        chrono::DateTime<chrono::Utc>,
        chrono::DateTime<chrono::Utc>,
    )> = sqlx::query_as(
        r#"SELECT id, user_id, status, note, created_at, updated_at FROM hosting_requests
           ORDER BY created_at DESC LIMIT 200"#,
    )
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    let out: Vec<serde_json::Value> = rows
        .into_iter()
        .map(|(id, user_id, status, note, created_at, updated_at)| {
            json!({
                "id": id.to_string(),
                "user_id": user_id.to_string(),
                "status": status,
                "note": note,
                "created_at": created_at,
                "updated_at": updated_at,
            })
        })
        .collect();
    HttpResponse::Ok().json(out)
}

pub async fn list_my_hosting_requests(
    state: web::Data<AppState>,
    req: HttpRequest,
) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let rows: Vec<(
        Uuid,
        String,
        Option<String>,
        chrono::DateTime<chrono::Utc>,
        chrono::DateTime<chrono::Utc>,
    )> = sqlx::query_as(
        r#"SELECT id, status, note, created_at, updated_at FROM hosting_requests
           WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50"#,
    )
    .bind(uid)
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    let out: Vec<serde_json::Value> = rows
        .into_iter()
        .map(|(id, status, note, created_at, updated_at)| {
            json!({
                "id": id.to_string(),
                "status": status,
                "note": note,
                "created_at": created_at,
                "updated_at": updated_at,
            })
        })
        .collect();
    HttpResponse::Ok().json(out)
}

#[derive(Deserialize)]
pub struct HostingPatchBody {
    pub status: String,
}

pub async fn patch_hosting_admin(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
    body: web::Json<HostingPatchBody>,
) -> impl Responder {
    let jwt_secret = match jwt_secret() {
        Ok(s) => s,
        Err(e) => return e,
    };
    let uid = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };
    if !is_admin(&state.pool, uid).await {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let id = path.into_inner();
    let st = body.status.trim();
    if !matches!(st, "requested" | "processing" | "done" | "cancelled") {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "status must be requested, processing, done, or cancelled".into(),
        });
    }

    let res = sqlx::query(
        r#"UPDATE hosting_requests SET status = $1, updated_at = now() WHERE id = $2"#,
    )
    .bind(st)
    .bind(id)
    .execute(&state.pool)
    .await;

    match res {
        Ok(r) if r.rows_affected() > 0 => {
            HttpResponse::Ok().json(json!({ "ok": true, "id": id.to_string(), "status": st }))
        }
        Ok(_) => HttpResponse::NotFound().json(ErrorResponse {
            error: "Hosting request not found".into(),
        }),
        Err(e) => {
            log::error!("patch_hosting_admin: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}
