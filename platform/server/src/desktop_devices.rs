use actix_web::{web, HttpRequest, HttpResponse, Responder};
use chrono::{Duration, Utc};
use rand::RngExt;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{create_token, get_user_id_from_token, ErrorResponse};

#[derive(Serialize)]
pub struct PairStartResponse {
    pub code: String,
    pub expires_at: String,
}

#[derive(Deserialize)]
pub struct PairConfirmBody {
    pub code: String,
}

#[derive(Deserialize)]
pub struct PairClaimBody {
    pub code: String,
    pub device_id: String,
    pub device_name: String,
    pub host_label: Option<String>,
    pub os_info: Option<String>,
}

#[derive(Serialize)]
pub struct PairClaimResponse {
    pub device_id: String,
    pub api_key: String,
    pub access_token: String,
    pub refresh_token: String,
    pub cloud_url: String,
}

#[derive(Serialize)]
pub struct DeviceRow {
    pub id: Uuid,
    pub device_id: String,
    pub device_name: String,
    pub host_label: Option<String>,
    pub os_info: Option<String>,
    pub sync_telemetry: bool,
    pub sync_tasks: bool,
    pub sync_projects: bool,
    pub last_seen_at: Option<String>,
    pub created_at: String,
}

#[derive(Deserialize)]
pub struct PatchDeviceBody {
    pub sync_telemetry: Option<bool>,
    pub sync_tasks: Option<bool>,
    pub sync_projects: Option<bool>,
    pub host_label: Option<String>,
}

#[derive(Deserialize)]
pub struct RefreshBody {
    pub refresh_token: String,
}

fn pairing_code() -> String {
    const ALPH: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    let mut rng = rand::rng();
    let mut s = String::from("WD-");
    for _ in 0..8 {
        let i = rng.random_range(0..ALPH.len());
        s.push(ALPH[i] as char);
    }
    s
}

fn hash_token(raw: &str) -> String {
    let mut h = Sha256::new();
    h.update(raw.as_bytes());
    hex::encode(h.finalize())
}

async fn user_from_session(req: &HttpRequest, _pool: &PgPool) -> Result<Uuid, HttpResponse> {
    let secret = std::env::var("JWT_SECRET").map_err(|_| {
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        })
    })?;
    get_user_id_from_token(req, &secret).ok_or_else(|| {
        HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        })
    })
}

fn issue_access_token(user_id: Uuid) -> Result<String, HttpResponse> {
    let secret = std::env::var("JWT_SECRET").map_err(|_| {
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        })
    })?;
    create_token(&user_id.to_string(), &secret, 24 * 7).map_err(|_| {
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Token error".into(),
        })
    })
}

pub async fn pair_start(state: web::Data<crate::AppState>, req: HttpRequest) -> impl Responder {
    let uid = match user_from_session(&req, &state.pool).await {
        Ok(u) => u,
        Err(r) => return r,
    };
    let code = pairing_code();
    let expires = Utc::now() + Duration::minutes(10);
    if let Err(e) = sqlx::query(
        "INSERT INTO desktop_pairing_codes (code, user_id, expires_at) VALUES ($1, $2, $3)",
    )
    .bind(&code)
    .bind(uid)
    .bind(expires)
    .execute(&state.pool)
    .await
    {
        log::error!("pair_start: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Database error".into(),
        });
    }
    HttpResponse::Ok().json(PairStartResponse {
        code,
        expires_at: expires.to_rfc3339(),
    })
}

pub async fn pair_confirm(
    state: web::Data<crate::AppState>,
    req: HttpRequest,
    body: web::Json<PairConfirmBody>,
) -> impl Responder {
    let uid = match user_from_session(&req, &state.pool).await {
        Ok(u) => u,
        Err(r) => return r,
    };
    let code = body.code.trim().to_uppercase();
    let row = sqlx::query_as::<_, (Uuid,)>(
        "SELECT user_id FROM desktop_pairing_codes WHERE code = $1 AND expires_at > now() AND claimed_device_id IS NULL",
    )
    .bind(&code)
    .fetch_optional(&state.pool)
    .await;

    match row {
        Ok(Some((owner,))) if owner == uid => HttpResponse::Ok().json(serde_json::json!({ "ok": true })),
        Ok(Some(_)) => HttpResponse::Forbidden().json(ErrorResponse {
            error: "Code belongs to another account".into(),
        }),
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "Invalid or expired code".into(),
        }),
        Err(e) => {
            log::error!("pair_confirm: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

pub async fn pair_claim(state: web::Data<crate::AppState>, body: web::Json<PairClaimBody>) -> impl Responder {
    let code = body.code.trim().to_uppercase();
    let pair = sqlx::query_as::<_, (Uuid,)>(
        "SELECT user_id FROM desktop_pairing_codes WHERE code = $1 AND expires_at > now() AND claimed_device_id IS NULL",
    )
    .bind(&code)
    .fetch_optional(&state.pool)
    .await;

    let user_id = match pair {
        Ok(Some((uid,))) => uid,
        Ok(None) => {
            return HttpResponse::NotFound().json(ErrorResponse {
                error: "Invalid or expired pairing code".into(),
            })
        }
        Err(e) => {
            log::error!("pair_claim lookup: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    let api_key_id = Uuid::new_v4();
    let raw_key = format!("wp_{}", Uuid::new_v4().simple());
    let device_row_id = Uuid::new_v4();

    let mut tx = match state.pool.begin().await {
        Ok(t) => t,
        Err(e) => {
            log::error!("pair_claim tx: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    if sqlx::query(
        "INSERT INTO api_keys (id, user_id, name, key, scope) VALUES ($1, $2, $3, $4, 'desktop')",
    )
    .bind(api_key_id)
    .bind(user_id)
    .bind(format!("Desktop: {}", body.device_name))
    .bind(&raw_key)
    .execute(&mut *tx)
    .await
    .is_err()
    {
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to create API key".into(),
        });
    }

    if sqlx::query(
        "INSERT INTO desktop_devices (id, user_id, device_id, device_name, api_key_id, host_label, os_info, last_seen_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, now())
         ON CONFLICT (user_id, device_id) DO UPDATE SET device_name = EXCLUDED.device_name, api_key_id = EXCLUDED.api_key_id, host_label = EXCLUDED.host_label, os_info = EXCLUDED.os_info, revoked_at = NULL, last_seen_at = now()",
    )
    .bind(device_row_id)
    .bind(user_id)
    .bind(&body.device_id)
    .bind(&body.device_name)
    .bind(api_key_id)
    .bind(&body.host_label)
    .bind(&body.os_info)
    .execute(&mut *tx)
    .await
    .is_err()
    {
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to register device".into(),
        });
    }

    let _ = sqlx::query("UPDATE desktop_pairing_codes SET claimed_device_id = $1 WHERE code = $2")
        .bind(device_row_id)
        .bind(&code)
        .execute(&mut *tx)
        .await;

    let access_token = match issue_access_token(user_id) {
        Ok(t) => t,
        Err(r) => return r,
    };

    let refresh_raw = format!("wpr_{}", Uuid::new_v4());
    let refresh_hash = hash_token(&refresh_raw);
    let refresh_exp = Utc::now() + Duration::days(90);
    let _ = sqlx::query(
        "INSERT INTO auth_refresh_tokens (user_id, token_hash, device_id, expires_at) VALUES ($1, $2, $3, $4)",
    )
    .bind(user_id)
    .bind(&refresh_hash)
    .bind(device_row_id)
    .bind(refresh_exp)
    .execute(&mut *tx)
    .await;

    if tx.commit().await.is_err() {
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Commit failed".into(),
        });
    }

    let cloud_url = std::env::var("WAYPOINT_PUBLIC_URL").unwrap_or_else(|_| "https://metrika-waypoint.ru".into());

    HttpResponse::Ok().json(PairClaimResponse {
        device_id: body.device_id.clone(),
        api_key: raw_key,
        access_token,
        refresh_token: refresh_raw,
        cloud_url,
    })
}

pub async fn token_refresh(state: web::Data<crate::AppState>, body: web::Json<RefreshBody>) -> impl Responder {
    let h = hash_token(body.refresh_token.trim());
    let row = sqlx::query_as::<_, (Uuid, Uuid)>(
        "SELECT user_id, id FROM auth_refresh_tokens WHERE token_hash = $1 AND expires_at > now() AND revoked_at IS NULL",
    )
    .bind(&h)
    .fetch_optional(&state.pool)
    .await;

    let (user_id, _tid) = match row {
        Ok(Some(r)) => r,
        Ok(None) => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid refresh token".into(),
            })
        }
        Err(e) => {
            log::error!("token_refresh: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    match issue_access_token(user_id) {
        Ok(access_token) => HttpResponse::Ok().json(serde_json::json!({ "access_token": access_token })),
        Err(r) => r,
    }
}

pub async fn list_devices(state: web::Data<crate::AppState>, req: HttpRequest) -> impl Responder {
    let uid = match user_from_session(&req, &state.pool).await {
        Ok(u) => u,
        Err(r) => return r,
    };
    let rows = sqlx::query_as::<_, (
        Uuid,
        String,
        String,
        Option<String>,
        Option<String>,
        bool,
        bool,
        bool,
        Option<chrono::DateTime<Utc>>,
        chrono::DateTime<Utc>,
    )>(
        "SELECT id, device_id, device_name, host_label, os_info, sync_telemetry, sync_tasks, sync_projects, last_seen_at, created_at
         FROM desktop_devices WHERE user_id = $1 AND revoked_at IS NULL ORDER BY last_seen_at DESC NULLS LAST",
    )
    .bind(uid)
    .fetch_all(&state.pool)
    .await;

    match rows {
        Ok(list) => {
            let out: Vec<DeviceRow> = list
                .into_iter()
                .map(|r| DeviceRow {
                    id: r.0,
                    device_id: r.1,
                    device_name: r.2,
                    host_label: r.3,
                    os_info: r.4,
                    sync_telemetry: r.5,
                    sync_tasks: r.6,
                    sync_projects: r.7,
                    last_seen_at: r.8.map(|t| t.to_rfc3339()),
                    created_at: r.9.to_rfc3339(),
                })
                .collect();
            HttpResponse::Ok().json(out)
        }
        Err(e) => {
            log::error!("list_devices: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

pub async fn patch_device(
    state: web::Data<crate::AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
    body: web::Json<PatchDeviceBody>,
) -> impl Responder {
    let uid = match user_from_session(&req, &state.pool).await {
        Ok(u) => u,
        Err(r) => return r,
    };
    let id = path.into_inner();
    let r = sqlx::query(
        "UPDATE desktop_devices SET
           sync_telemetry = COALESCE($3, sync_telemetry),
           sync_tasks = COALESCE($4, sync_tasks),
           sync_projects = COALESCE($5, sync_projects),
           host_label = COALESCE($6, host_label)
         WHERE id = $1 AND user_id = $2 AND revoked_at IS NULL",
    )
    .bind(id)
    .bind(uid)
    .bind(body.sync_telemetry)
    .bind(body.sync_tasks)
    .bind(body.sync_projects)
    .bind(&body.host_label)
    .execute(&state.pool)
    .await;

    match r {
        Ok(x) if x.rows_affected() > 0 => HttpResponse::Ok().json(serde_json::json!({ "ok": true })),
        Ok(_) => HttpResponse::NotFound().finish(),
        Err(e) => {
            log::error!("patch_device: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

pub async fn revoke_device(
    state: web::Data<crate::AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    let uid = match user_from_session(&req, &state.pool).await {
        Ok(u) => u,
        Err(r) => return r,
    };
    let id = path.into_inner();
    let _ = sqlx::query(
        "UPDATE desktop_devices SET revoked_at = now() WHERE id = $1 AND user_id = $2",
    )
    .bind(id)
    .bind(uid)
    .execute(&state.pool)
    .await;
    let _ = sqlx::query(
        "UPDATE auth_refresh_tokens SET revoked_at = now() WHERE device_id = $1",
    )
    .bind(id)
    .execute(&state.pool)
    .await;
    HttpResponse::Ok().json(serde_json::json!({ "ok": true }))
}

pub async fn desktop_heartbeat(
    state: web::Data<crate::AppState>,
    req: HttpRequest,
    body: web::Json<serde_json::Value>,
) -> impl Responder {
    let api_key = req
        .headers()
        .get("X-API-Key")
        .and_then(|h| h.to_str().ok());
    let Some(key) = api_key else {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Missing API key".into(),
        });
    };
    let host = body.get("host_label").and_then(|v| v.as_str());
    let os = body.get("os_info").and_then(|v| v.as_str());
    let _ = sqlx::query(
        "UPDATE desktop_devices d SET last_seen_at = now(), host_label = COALESCE($2, host_label), os_info = COALESCE($3, os_info)
         FROM api_keys k WHERE d.api_key_id = k.id AND k.key = $1 AND d.revoked_at IS NULL",
    )
    .bind(key)
    .bind(host)
    .bind(os)
    .execute(&state.pool)
    .await;
    HttpResponse::Ok().json(serde_json::json!({ "ok": true }))
}

pub async fn list_desktop_hosts(state: web::Data<crate::AppState>, req: HttpRequest) -> impl Responder {
    list_devices(state, req).await
}
