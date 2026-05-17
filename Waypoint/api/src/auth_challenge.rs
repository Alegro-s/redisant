use actix_web::{web, HttpRequest, HttpResponse, Responder};
use chrono::Utc;
use rand::RngExt;
use serde::{Deserialize, Serialize};
use serde_json::json;
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use std::env;
use uuid::Uuid;

use crate::{auth_json_for_user, blocking, client_realm_from_header, user_has_realm, AppState, ErrorResponse};

const CHANNEL_EMAIL: &str = "email";
const CHANNEL_SMS: &str = "sms";
const CHANNEL_NEXUS: &str = "nexus";

#[derive(Deserialize)]
pub struct PreviewRequest {
    pub login: String,
    pub password: String,
}

#[derive(Serialize)]
pub struct PreviewResponse {
    pub channels: Vec<String>,
}

#[derive(Deserialize)]
pub struct StartRequest {
    pub login: String,
    pub password: String,
    pub channel: String,
}

#[derive(Serialize)]
pub struct StartResponse {
    pub challenge_id: String,
    pub session_token: String,
    pub expires_in_secs: i64,
    pub channel: String,
    pub delivery_hint: String,
}

#[derive(Deserialize)]
pub struct VerifyRequest {
    pub challenge_id: String,
    pub session_token: String,
    pub code: String,
}

#[derive(Deserialize)]
pub struct NexusCodeQuery {
    pub challenge_id: String,
    pub session_token: String,
}

fn otp_pepper() -> String {
    env::var("OTP_CODE_PEPPER")
        .ok()
        .filter(|s| !s.is_empty())
        .or_else(|| env::var("JWT_SECRET").ok())
        .unwrap_or_else(|| "dev-otp-pepper-change-me".into())
}

fn hash_otp(pepper: &str, code: &str) -> String {
    let mut h = Sha256::new();
    h.update(pepper.as_bytes());
    h.update(b"|otp|");
    h.update(code.trim().as_bytes());
    format!("{:x}", h.finalize())
}

fn hash_session(pepper: &str, token: &str) -> String {
    let mut h = Sha256::new();
    h.update(pepper.as_bytes());
    h.update(b"|session|");
    h.update(token.as_bytes());
    format!("{:x}", h.finalize())
}

fn gen_code_6() -> String {
    let mut rng = rand::rng();
    let n: u32 = rng.random_range(100_000..=999_999);
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

fn mask_email(e: &str) -> String {
    let parts: Vec<&str> = e.split('@').collect();
    if parts.len() != 2 {
        return "•••".into();
    }
    let name = parts[0];
    let dom = parts[1];
    let prefix: String = name.chars().take(2).collect();
    format!("{prefix}•••@{dom}")
}

fn mask_phone(p: &str) -> String {
    let d: String = p.chars().filter(|c| c.is_ascii_digit()).collect();
    if d.len() <= 4 {
        return "•••".into();
    }
    format!("••••{}", &d[d.len().saturating_sub(4)..])
}

async fn verify_password(
    pool: &PgPool,
    login: &str,
    password: &str,
) -> Result<(Uuid, String, String, Option<String>, bool), String> {
    let user = sqlx::query_as::<_, (Uuid, String, String, String, Option<String>, bool)>(
        r#"SELECT id, nickname, email, password_hash, phone, email_verified FROM users
           WHERE lower(trim(email)) = lower(trim($1)) OR LOWER(nickname) = LOWER($1)"#,
    )
    .bind(login.trim())
    .fetch_optional(pool)
    .await
    .map_err(|e| e.to_string())?;

    let (user_id, nickname, email, hash, phone, email_verified) = match user {
        Some(u) => u,
        None => return Err("Invalid login or password".into()),
    };

    let ok = blocking::bcrypt_verify_password(password, &hash)
        .await
        .map_err(|_| "Authentication error".to_string())?;
    if !ok {
        return Err("Invalid login or password".into());
    }
    Ok((user_id, nickname, email, phone, email_verified))
}

fn channels_for_user(email: &str, phone: &Option<String>) -> Vec<String> {
    let mut v = Vec::new();
    if !email.is_empty() {
        v.push(CHANNEL_EMAIL.into());
    }
    if phone.as_ref().map(|s| !s.trim().is_empty()).unwrap_or(false) {
        v.push(CHANNEL_SMS.into());
    }
    v.push(CHANNEL_NEXUS.into());
    v
}

pub async fn challenge_preview(state: web::Data<AppState>, body: web::Json<PreviewRequest>) -> impl Responder {
    let pool = &state.pool;
    let (user_id, nickname, email, phone, email_verified) =
        match verify_password(pool, &body.login, &body.password).await {
            Ok(u) => u,
            Err(e) => {
                return HttpResponse::Unauthorized().json(ErrorResponse { error: e });
            }
        };

    if !email_verified {
        return HttpResponse::Forbidden().json(json!({
            "error": "Подтвердите email: введите код из письма или запросите его повторно.",
            "error_code": "email_not_verified",
            "email": email,
        }));
    }

    let _ = (user_id, nickname);
    let ch = channels_for_user(&email, &phone);
    HttpResponse::Ok().json(PreviewResponse { channels: ch })
}

fn delivery_hint(channel: &str, email: &str, phone: &Option<String>) -> String {
    match channel {
        CHANNEL_EMAIL => format!("Код отправлен на {}", mask_email(email)),
        CHANNEL_SMS => format!(
            "Код отправлен на номер {}",
            phone.as_ref().map(|p| mask_phone(p)).unwrap_or_else(|| "•••".into())
        ),
        CHANNEL_NEXUS => "NEXUS Auth: наберите «Показать код» ниже или откройте экран подтверждения.".into(),
        _ => "Проверьте выбранный канал.".into(),
    }
}

async fn send_webhook_or_log(
    channel: &str,
    login: &str,
    email: &str,
    phone: &Option<String>,
    code: &str,
) {
    let (url, secret, log_codes) = webhook_config();
    if let Some(ref u) = url {
        let client = match reqwest::Client::builder().timeout(std::time::Duration::from_secs(10)).build() {
            Ok(c) => c,
            Err(e) => {
                log::error!("otp webhook client: {}", e);
                return;
            }
        };
        let to_email = if channel == CHANNEL_EMAIL { email } else { "" };
        let to_phone = phone.as_deref().unwrap_or("");
        let body = json!({
            "channel": channel,
            "login": login,
            "to_email": to_email,
            "to_phone": to_phone,
            "code": code,
        });
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
                let preview: String = body_txt.chars().take(400).collect();
                if status.is_success() {
                    if preview.contains("\"ok\":false") || preview.contains("\"ok\": false") {
                        log::warn!(
                            "OTP webhook ok=false for {} channel={}: {}",
                            login,
                            channel,
                            preview
                        );
                    } else {
                        log::info!("OTP webhook OK for {} ({})", login, channel);
                    }
                } else {
                    log::warn!(
                        "OTP webhook HTTP {} for {} channel={}: {}",
                        status,
                        login,
                        channel,
                        preview
                    );
                }
            }
            Err(e) => {
                log::error!("OTP webhook error: {}", e);
            }
        }
    } else if log_codes {
        log::warn!(
            "OTP_LOG_CODES login={} channel={} code={} (no OTP_WEBHOOK_URL)",
            login,
            channel,
            code
        );
    } else if channel == CHANNEL_EMAIL || channel == CHANNEL_SMS {
        log::warn!(
            "OTP not delivered: set OTP_WEBHOOK_URL (+ OTP_WEBHOOK_SECRET) or OTP_LOG_CODES=1 for dev. login={} channel={}",
            login,
            channel
        );
    }
}

pub async fn challenge_start(state: web::Data<AppState>, body: web::Json<StartRequest>) -> impl Responder {
    let pool = &state.pool;

    let channel = body.channel.trim().to_lowercase();
    if channel != CHANNEL_EMAIL && channel != CHANNEL_SMS && channel != CHANNEL_NEXUS {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid channel: use email, sms, or nexus".into(),
        });
    }

    let (user_id, _nickname, email, phone, email_verified) =
        match verify_password(pool, &body.login, &body.password).await {
            Ok(u) => u,
            Err(e) => {
                return HttpResponse::Unauthorized().json(ErrorResponse { error: e });
            }
        };

    if !email_verified {
        return HttpResponse::Forbidden().json(json!({
            "error": "Подтвердите email: введите код из письма или запросите его повторно.",
            "error_code": "email_not_verified",
            "email": email,
        }));
    }

    if channel == CHANNEL_SMS && !phone.as_ref().map(|s| !s.trim().is_empty()).unwrap_or(false) {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "В профиле нет номера телефона. Укажите телефон при регистрации или в настройках.".into(),
        });
    }

    let code = gen_code_6();
    let pepper = otp_pepper();
    let code_hash = hash_otp(&pepper, &code);
    let session_token = Uuid::new_v4().to_string();
    let session_hash = hash_session(&pepper, &session_token);

    let challenge_id = Uuid::new_v4();
    let expires_at = Utc::now() + chrono::Duration::minutes(10);
    let nexus_plain = if channel == CHANNEL_NEXUS { Some(code.clone()) } else { None };

    let ins = sqlx::query(
        r#"INSERT INTO login_otp_challenges
        (id, user_id, channel, code_hash, nexus_code_plain, session_token_hash, expires_at)
        VALUES ($1,$2,$3,$4,$5,$6,$7)"#,
    )
    .bind(challenge_id)
    .bind(user_id)
    .bind(&channel)
    .bind(&code_hash)
    .bind(&nexus_plain)
    .bind(&session_hash)
    .bind(expires_at)
    .execute(pool)
    .await;

    if let Err(e) = ins {
        log::error!("login_otp insert: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to create challenge".into(),
        });
    }

    let hint = delivery_hint(&channel, &email, &phone);
    let login_owned = body.login.trim().to_string();
    let email_owned = email.clone();
    let phone_clone = phone.clone();
    let ch = channel.clone();
    let code_clone = code.clone();
    tokio::spawn(async move {
        send_webhook_or_log(&ch, &login_owned, &email_owned, &phone_clone, &code_clone).await;
    });

    HttpResponse::Ok().json(StartResponse {
        challenge_id: challenge_id.to_string(),
        session_token,
        expires_in_secs: 600,
        channel,
        delivery_hint: hint,
    })
}

pub async fn nexus_reveal(state: web::Data<AppState>, req: HttpRequest, q: web::Query<NexusCodeQuery>) -> impl Responder {
    let pool = &state.pool;
    let Ok(cid) = Uuid::parse_str(&q.challenge_id) else {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid challenge_id".into(),
        });
    };

    let pepper = otp_pepper();
    let session_hash = hash_session(&pepper, &q.session_token);

    let row = sqlx::query_as::<_, (String, Option<String>, bool, chrono::DateTime<Utc>)>(
        r#"SELECT channel, nexus_code_plain, consumed, expires_at
           FROM login_otp_challenges WHERE id = $1 AND session_token_hash = $2"#,
    )
    .bind(cid)
    .bind(&session_hash)
    .fetch_optional(pool)
    .await;

    let row = match row {
        Ok(Some(r)) => r,
        Ok(None) => {
            return HttpResponse::NotFound().json(ErrorResponse {
                error: "Challenge not found".into(),
            });
        }
        Err(e) => {
            log::error!("nexus_reveal: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    let (channel, plain, consumed, exp) = row;
    if consumed || Utc::now() > exp {
        return HttpResponse::Gone().json(ErrorResponse {
            error: "Challenge expired or used".into(),
        });
    }
    if channel != CHANNEL_NEXUS {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "NEXUS code delivery only for channel=nexus".into(),
        });
    }

    let code = match plain {
        Some(c) => c,
        None => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Code not available".into(),
            });
        }
    };

    let _ = req;
    HttpResponse::Ok().json(json!({ "code": code }))
}

pub async fn challenge_verify(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<VerifyRequest>,
) -> impl Responder {
    let pool = &state.pool;
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) if !s.is_empty() => s,
        _ => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            });
        }
    };

    let Ok(cid) = Uuid::parse_str(&body.challenge_id) else {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid challenge_id".into(),
        });
    };

    let code_norm = body.code.trim();
    if code_norm.len() != 6 || !code_norm.chars().all(|c| c.is_ascii_digit()) {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Код — 6 цифр".into(),
        });
    }

    let pepper = otp_pepper();
    let session_hash = hash_session(&pepper, &body.session_token);
    let expect_hash = hash_otp(&pepper, code_norm);

    let row = sqlx::query_as::<_, (Uuid, bool, chrono::DateTime<Utc>)>(
        r#"SELECT user_id, consumed, expires_at FROM login_otp_challenges
           WHERE id = $1 AND session_token_hash = $2 AND code_hash = $3"#,
    )
    .bind(cid)
    .bind(&session_hash)
    .bind(&expect_hash)
    .fetch_optional(pool)
    .await;

    let (user_id, consumed, exp) = match row {
        Ok(Some(r)) => r,
        Ok(None) => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Неверный код или сессия".into(),
            });
        }
        Err(e) => {
            log::error!("challenge_verify: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    if consumed || Utc::now() > exp {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Код просрочен или уже использован".into(),
        });
    }

    let verified: bool = sqlx::query_scalar("SELECT COALESCE(email_verified, true) FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_one(pool)
        .await
        .unwrap_or(true);
    if !verified {
        return HttpResponse::Forbidden().json(json!({
            "error": "Подтвердите email перед входом.",
            "error_code": "email_not_verified",
        }));
    }

    if let Err(e) = sqlx::query("UPDATE login_otp_challenges SET consumed = true WHERE id = $1")
        .bind(cid)
        .execute(pool)
        .await
    {
        log::error!("consume challenge: {}", e);
    }

    if let Some(realm) = client_realm_from_header(&req) {
        if !user_has_realm(pool, user_id, realm).await {
            let msg = if realm == "metric" {
                "Нет доступа к Метрике для этого аккаунта. Подключите продукт в профиле NEXUS."
            } else {
                "Нет доступа к NEXUS для этого аккаунта. Подключите продукт в веб-консоли Метрика."
            };
            return HttpResponse::Forbidden().json(ErrorResponse {
                error: msg.into(),
            });
        }
    }

    let nick: Option<String> = sqlx::query_scalar("SELECT nickname FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .ok()
        .flatten();

    let nickname = nick.unwrap_or_else(|| "user".into());

    let ttl = state.config.session_jwt_ttl_hours;
    match auth_json_for_user(pool, user_id, &nickname, &jwt_secret, ttl).await {
        Ok(auth) => {
            let max_age = ttl.max(1) * 3600;
            HttpResponse::Ok()
                .cookie(crate::session::session_cookie(
                    &auth.token,
                    max_age,
                    state.config.session_cookie_secure,
                ))
                .json(auth)
        }
        Err(e) => {
            log::error!("auth_json_for_user: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Token error".into(),
            })
        }
    }
}
