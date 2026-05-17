
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use chrono::Utc;
use rand::RngExt;
use serde::Deserialize;
use serde_json::json;
use sha2::{Digest, Sha256};
use std::env;
use uuid::Uuid;

use crate::session;
use crate::{auth_json_for_user, AppState, ErrorResponse};

const VERIFY_CODE_TTL_HOURS: i64 = 24;
const RESEND_COOLDOWN_SECS: i64 = 60;

fn pepper() -> String {
    env::var("OTP_CODE_PEPPER")
        .ok()
        .filter(|s| !s.is_empty())
        .or_else(|| env::var("JWT_SECRET").ok())
        .unwrap_or_else(|| "dev-email-verify-pepper".into())
}

fn hash_code(pepper: &str, code: &str) -> String {
    let mut h = Sha256::new();
    h.update(pepper.as_bytes());
    h.update(b"|email_verify|");
    h.update(code.trim().as_bytes());
    format!("{:x}", h.finalize())
}

pub fn new_registration_code() -> String {
    gen_code_8()
}

fn gen_code_8() -> String {
    let mut rng = rand::rng();
    let n: u32 = rng.random_range(10_000_000..=99_999_999);
    format!("{n}")
}

fn webhook_config() -> (Option<String>, String, bool) {
    let url = env::var("OTP_WEBHOOK_URL").ok().filter(|s| !s.is_empty());
    let secret = env::var("OTP_WEBHOOK_SECRET").unwrap_or_default();
    let log = env::var("OTP_LOG_CODES")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(false);
    (url, secret, log)
}

pub fn spawn_send_registration_code(nickname: String, email: String, code: String) {
    let verify_base = env::var("PUBLIC_WEB_BASE_URL")
        .ok()
        .filter(|s| !s.is_empty())
        .map(|s| s.trim_end_matches('/').to_string());
    tokio::spawn(async move {
        send_registration_webhook(&nickname, &email, &code, verify_base.as_deref()).await;
    });
}

async fn send_registration_webhook(
    nickname: &str,
    email: &str,
    code: &str,
    verify_base: Option<&str>,
) {
    let (url, secret, log_codes) = webhook_config();
    let verify_url = verify_base.map(|b| {
        format!(
            "{}/verify-email?email={}",
            b,
            urlencoding::encode(email)
        )
    });

    let body = json!({
        "purpose": "email_verification",
        "channel": "email",
        "login": nickname,
        "to_email": email,
        "to_phone": "",
        "code": code,
        "verify_url": verify_url,
    });

    if let Some(ref u) = url {
        let client = match reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(15))
            .build()
        {
            Ok(c) => c,
            Err(e) => {
                log::error!("registration email webhook client: {}", e);
                return;
            }
        };
        match client
            .post(u)
            .header("Content-Type", "application/json")
            .header("X-Nexus-Webhook-Secret", &secret)
            .json(&body)
            .send()
            .await
        {
            Ok(resp) => {
                let status = resp.status();
                let body_txt = resp.text().await.unwrap_or_default();
                let preview: String = body_txt.chars().take(500).collect();
                if status.is_success() {
                    if preview.contains("\"ok\":false") || preview.contains("\"ok\": false") {
                        log::warn!(
                            "registration verification webhook ok=false for {}: {}",
                            email,
                            preview
                        );
                    } else {
                        log::info!("registration verification webhook OK for {}", email);
                    }
                } else {
                    log::warn!(
                        "registration verification webhook HTTP {} for {}: {}",
                        status,
                        email,
                        preview
                    );
                }
            }
            Err(e) => {
                log::error!("registration verification webhook: {}", e);
            }
        }
    } else if log_codes {
        log::warn!(
            "REGISTRATION VERIFY (no OTP_WEBHOOK_URL) email={} code={}",
            email,
            code
        );
    } else {
        log::warn!(
            "Регистрация: письмо с кодом не отправлено. Задайте OTP_WEBHOOK_URL или OTP_LOG_CODES=1 для отладки (email={})",
            email
        );
    }
}

pub(crate) async fn insert_pending_code(pool: &mut sqlx::Transaction<'_, sqlx::Postgres>, user_id: Uuid, code_plain: &str) -> Result<(), sqlx::Error> {
    let p = pepper();
    let code_hash = hash_code(&p, code_plain);
    let expires = Utc::now() + chrono::Duration::hours(VERIFY_CODE_TTL_HOURS);
    sqlx::query(
        r#"INSERT INTO email_verification_pending (user_id, code_hash, expires_at, last_sent_at)
           VALUES ($1, $2, $3, now())
           ON CONFLICT (user_id) DO UPDATE
           SET code_hash = EXCLUDED.code_hash, expires_at = EXCLUDED.expires_at, last_sent_at = now()"#,
    )
    .bind(user_id)
    .bind(&code_hash)
    .bind(expires)
    .execute(&mut **pool)
    .await?;
    Ok(())
}

#[derive(Deserialize)]
pub struct VerifyEmailBody {
    pub email: String,
    pub code: String,
}

pub async fn verify_email(state: web::Data<AppState>, http_req: HttpRequest, body: web::Json<VerifyEmailBody>) -> impl Responder {
    let email = body.email.trim().to_lowercase();
    let code = body.code.chars().filter(|c| c.is_ascii_digit()).collect::<String>();
    if email.is_empty() || code.len() < 8 {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Укажите email и 8-значный код из письма.".into(),
        });
    }

    let row = sqlx::query_as::<_, (Uuid, String, bool)>(
        r#"SELECT u.id, u.nickname, u.email_verified FROM users u
           WHERE lower(trim(u.email)) = $1"#,
    )
    .bind(&email)
    .fetch_optional(&state.pool)
    .await;

    let (user_id, nickname, already) = match row {
        Ok(Some(r)) => r,
        Ok(None) => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "Пользователь с таким email не найден.".into(),
            });
        }
        Err(e) => {
            log::error!("verify_email select user: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    if already {
        let jwt_secret = match env::var("JWT_SECRET") {
            Ok(s) => s,
            Err(_) => {
                return HttpResponse::InternalServerError().json(ErrorResponse {
                    error: "Server configuration error".into(),
                });
            }
        };
        let ttl = state.config.session_jwt_ttl_hours;
        let realm = crate::client_realm_from_header(&http_req);
        if let Some(r) = realm {
            if !crate::user_has_realm(&state.pool, user_id, r).await {
                let msg = if r == "metric" {
                    "Нет доступа к Метрике для этого аккаунта."
                } else {
                    "Нет доступа к NEXUS для этого аккаунта."
                };
                return HttpResponse::Forbidden().json(ErrorResponse {
                    error: msg.into(),
                });
            }
        }
        match auth_json_for_user(&state.pool, user_id, &nickname, &jwt_secret, ttl).await {
            Ok(auth) => {
                let token = auth.token.clone();
                return HttpResponse::Ok()
                    .cookie(session::session_cookie(
                        &token,
                        ttl.max(1) * 3600,
                        state.config.session_cookie_secure,
                    ))
                    .json(auth);
            }
            Err(e) => {
                log::error!("verify_email auth already verified: {}", e);
                return HttpResponse::InternalServerError().json(ErrorResponse {
                    error: "Failed to issue session".into(),
                });
            }
        }
    }

    let pending = sqlx::query_as::<_, (String, chrono::DateTime<Utc>)>(
        "SELECT code_hash, expires_at FROM email_verification_pending WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(&state.pool)
    .await;

    let (stored_hash, exp) = match pending {
        Ok(Some(r)) => r,
        Ok(None) => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "Нет ожидающего кода. Запросите письмо повторно.".into(),
            });
        }
        Err(e) => {
            log::error!("verify_email pending: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    if Utc::now() > exp {
        let _ = sqlx::query("DELETE FROM email_verification_pending WHERE user_id = $1")
            .bind(user_id)
            .execute(&state.pool)
            .await;
        return HttpResponse::Gone().json(ErrorResponse {
            error: "Срок кода истёк. Запросите новый.".into(),
        });
    }

    let p = pepper();
    let got = hash_code(&p, &code);
    if !got.eq_ignore_ascii_case(&stored_hash) {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Неверный код.".into(),
        });
    }

    let mut tx = match state.pool.begin().await {
        Ok(t) => t,
        Err(e) => {
            log::error!("verify_email tx: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    if let Err(e) = sqlx::query("UPDATE users SET email_verified = true WHERE id = $1")
        .bind(user_id)
        .execute(&mut *tx)
        .await
    {
        log::error!("verify_email update user: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Database error".into(),
        });
    }

    if let Err(e) = sqlx::query("DELETE FROM email_verification_pending WHERE user_id = $1")
        .bind(user_id)
        .execute(&mut *tx)
        .await
    {
        log::error!("verify_email delete pending: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Database error".into(),
        });
    }

    if let Err(e) = tx.commit().await {
        log::error!("verify_email commit: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Database error".into(),
        });
    }

    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            });
        }
    };

    let ttl = state.config.session_jwt_ttl_hours;
    let auth = match auth_json_for_user(&state.pool, user_id, &nickname, &jwt_secret, ttl).await {
        Ok(a) => a,
        Err(e) => {
            log::error!("verify_email auth: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to generate token".into(),
            });
        }
    };

    let realm = crate::client_realm_from_header(&http_req);
    if let Some(r) = realm {
        if !crate::user_has_realm(&state.pool, user_id, r).await {
            let msg = if r == "metric" {
                "Нет доступа к Метрике для этого аккаунта."
            } else {
                "Нет доступа к NEXUS для этого аккаунта."
            };
            return HttpResponse::Forbidden().json(ErrorResponse {
                error: msg.into(),
            });
        }
    }

    let token = auth.token.clone();
    HttpResponse::Ok()
        .cookie(session::session_cookie(
            &token,
            ttl.max(1) * 3600,
            state.config.session_cookie_secure,
        ))
        .json(auth)
}

#[derive(Deserialize)]
pub struct ResendBody {
    pub email: String,
}

pub async fn resend_verification(state: web::Data<AppState>, body: web::Json<ResendBody>) -> impl Responder {
    let email = body.email.trim().to_lowercase();
    if email.is_empty() {
        return HttpResponse::Ok().json(json!({ "ok": true, "message": "Если аккаунт существует, письмо отправлено." }));
    }

    let user = sqlx::query_as::<_, (Uuid, String, bool)>(
        r#"SELECT id, nickname, email_verified FROM users WHERE lower(trim(email)) = $1"#,
    )
    .bind(&email)
    .fetch_optional(&state.pool)
    .await;

    let (user_id, nickname, verified) = match user {
        Ok(Some(r)) => r,
        Ok(None) => {
            return HttpResponse::Ok().json(json!({ "ok": true, "message": "Если аккаунт существует, письмо отправлено." }));
        }
        Err(e) => {
            log::error!("resend select: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    if verified {
        return HttpResponse::Ok().json(json!({ "ok": true, "message": "Если аккаунт существует, письмо отправлено." }));
    }

    let cooldown = sqlx::query_scalar::<_, Option<chrono::DateTime<Utc>>>(
        "SELECT last_sent_at FROM email_verification_pending WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_optional(&state.pool)
    .await;

    if let Ok(Some(Some(ts))) = cooldown {
        let elapsed = Utc::now().signed_duration_since(ts).num_seconds();
        if elapsed < RESEND_COOLDOWN_SECS {
            return HttpResponse::TooManyRequests().json(ErrorResponse {
                error: format!(
                    "Подождите ещё {} сек. перед повторной отправкой.",
                    RESEND_COOLDOWN_SECS - elapsed
                ),
            });
        }
    }

    let code = gen_code_8();
    let mut tx = match state.pool.begin().await {
        Ok(t) => t,
        Err(e) => {
            log::error!("resend tx: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    if let Err(e) = insert_pending_code(&mut tx, user_id, &code).await {
        log::error!("resend insert pending: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Database error".into(),
        });
    }

    if let Err(e) = tx.commit().await {
        log::error!("resend commit: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Database error".into(),
        });
    }

    let nick = nickname.clone();
    let em = email.clone();
    let code_clone = code.clone();
    spawn_send_registration_code(nick, em, code_clone);

    HttpResponse::Ok().json(json!({ "ok": true, "message": "Код отправлен на email." }))
}
