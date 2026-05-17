
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use aes_gcm::aead::{Aead, KeyInit};
use aes_gcm::{Aes256Gcm, Nonce};
use rand_core::Rng;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs;
use std::path::Path;

use crate::{get_user_id_from_token, AppState, ErrorResponse};

#[derive(Deserialize)]
pub struct EngineSessionBody {
    pub version: String,
}

#[derive(Serialize)]
pub struct EngineSessionResponse {
    pub token: String,
    pub download_url: String,
    pub decryption_key_b64: String,
    pub expires_at: chrono::DateTime<chrono::Utc>,
}

fn jwt_secret() -> Result<String, HttpResponse> {
    std::env::var("JWT_SECRET").map_err(|_| {
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        })
    })
}

fn hash_token(token: &str) -> String {
    let mut h = Sha256::new();
    h.update(token.as_bytes());
    format!("{:x}", h.finalize())
}

pub async fn create_engine_session(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<EngineSessionBody>,
) -> impl Responder {
    let jwt_secret = match jwt_secret() {
        Ok(s) => s,
        Err(e) => return e,
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let version = body.version.trim().to_string();
    if version.is_empty() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "version required".into(),
        });
    }

    let mut raw_token = [0u8; 32];
    let mut rng = rand::rng();
    rng.fill_bytes(&mut raw_token);
    let token = hex::encode(raw_token);
    let token_hash = hash_token(&token);

    let mut aes_key = [0u8; 32];
    rng.fill_bytes(&mut aes_key);

    let expires_at = chrono::Utc::now() + chrono::Duration::minutes(15);

    if let Err(e) = sqlx::query(
        r#"INSERT INTO engine_download_tokens (user_id, version, token_hash, aes_key, expires_at)
           VALUES ($1, $2, $3, $4, $5)"#,
    )
    .bind(user_id)
    .bind(&version)
    .bind(&token_hash)
    .bind(&aes_key[..])
    .bind(expires_at)
    .execute(&state.pool)
    .await
    {
        log::error!("engine session: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Database error".into(),
        });
    }

    let key_b64 = base64::Engine::encode(
        &base64::engine::general_purpose::STANDARD,
        aes_key,
    );

    let v_enc = urlencoding::encode(&version);
    HttpResponse::Ok().json(EngineSessionResponse {
        token: token.clone(),
        download_url: format!("/engine/blob/{}?t={}", v_enc, token),
        decryption_key_b64: key_b64,
        expires_at,
    })
}

pub async fn download_engine_blob(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<String>,
) -> impl Responder {
    let version_raw = path.into_inner();
    let version = urlencoding::decode(&version_raw)
        .unwrap_or_else(|_| std::borrow::Cow::from(version_raw.as_str()));
    let token = req
        .query_string()
        .split('&')
        .find_map(|p| {
            let mut kv = p.splitn(2, '=');
            let k = kv.next()?;
            if k.eq_ignore_ascii_case("t") {
                Some(kv.next().unwrap_or("").to_string())
            } else {
                None
            }
        })
        .unwrap_or_default();

    if token.is_empty() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "missing token".into(),
        });
    }

    let token_hash = hash_token(&token);

    let row: Option<(uuid::Uuid, Vec<u8>, chrono::DateTime<chrono::Utc>, bool)> = sqlx::query_as(
        r#"SELECT id, aes_key, expires_at, consumed FROM engine_download_tokens
           WHERE token_hash = $1 AND version = $2"#,
    )
    .bind(&token_hash)
    .bind(version.as_ref())
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    let Some((id, aes_key, exp, consumed)) = row else {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "invalid or expired token".into(),
        });
    };

    if consumed || exp < chrono::Utc::now() {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "token expired or used".into(),
        });
    }

    let path = format!("./uploads/engine/{}.nexus", version.as_ref());
    let plaintext = if Path::new(&path).exists() {
        fs::read(&path).unwrap_or_else(|_| placeholder_nexus(version.as_ref()))
    } else {
        placeholder_nexus(version.as_ref())
    };

    let cipher = Aes256Gcm::new_from_slice(&aes_key).unwrap();
    let mut nonce_bytes = [0u8; 12];
    rand::rng().fill_bytes(&mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);
    let ciphertext = match cipher.encrypt(&nonce, plaintext.as_ref()) {
        Ok(c) => c,
        Err(e) => {
            log::error!("encrypt: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "encrypt failed".into(),
            });
        }
    };

    let mut out = Vec::with_capacity(nonce.len() + ciphertext.len());
    out.extend_from_slice(nonce.as_slice());
    out.extend_from_slice(&ciphertext);

    let _ = sqlx::query("UPDATE engine_download_tokens SET consumed = true WHERE id = $1")
        .bind(id)
        .execute(&state.pool)
        .await;

    HttpResponse::Ok()
        .content_type("application/octet-stream")
        .append_header(("X-Nexus-Nonce-Len", "12"))
        .body(out)
}

fn placeholder_nexus(version: &str) -> Vec<u8> {
    format!(
        "{{\"version\":\"{}\",\"format\":\"nexus-core\",\"placeholder\":true}}",
        version
    )
    .into_bytes()
}
