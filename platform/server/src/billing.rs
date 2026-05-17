
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use base64::{engine::general_purpose::STANDARD, Engine as _};
use hmac::{Hmac, Mac};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::Sha256;
use uuid::Uuid;

use crate::{get_user_id_from_token, is_admin, AppState, ErrorResponse};

type HmacSha256 = Hmac<Sha256>;

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

fn payment_providers_configured() -> serde_json::Value {
    let stripe = std::env::var("STRIPE_SECRET_KEY")
        .ok()
        .filter(|s| !s.is_empty())
        .is_some();
    let yk = std::env::var("YOOKASSA_SHOP_ID")
        .ok()
        .filter(|s| !s.is_empty())
        .is_some()
        && std::env::var("YOOKASSA_SECRET_KEY")
            .ok()
            .filter(|s| !s.is_empty())
            .is_some();
    json!({ "stripe": stripe, "yookassa": yk })
}

#[derive(Serialize, sqlx::FromRow)]
struct BillingAccountRow {
    plan: String,
    status: String,
    stripe_customer_id: Option<String>,
    yookassa_customer_id: Option<String>,
    current_period_end: Option<chrono::DateTime<chrono::Utc>>,
    balance_cents: i32,
}

pub async fn get_my_billing(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };

    let row: Option<BillingAccountRow> = sqlx::query_as(
        r#"SELECT plan, status, stripe_customer_id, yookassa_customer_id, current_period_end, balance_cents
           FROM billing_accounts WHERE user_id = $1"#,
    )
    .bind(uid)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    let account = match row {
        Some(r) => json!({
            "plan": r.plan,
            "status": r.status,
            "stripe_customer_id": r.stripe_customer_id,
            "yookassa_customer_id": r.yookassa_customer_id,
            "current_period_end": r.current_period_end,
            "balance_cents": r.balance_cents,
        }),
        None => {
            let _ = sqlx::query(
                "INSERT INTO billing_accounts (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING",
            )
            .bind(uid)
            .execute(&state.pool)
            .await;
            json!({
                "plan": "free",
                "status": "active",
                "stripe_customer_id": serde_json::Value::Null,
                "yookassa_customer_id": serde_json::Value::Null,
                "current_period_end": serde_json::Value::Null,
                "balance_cents": 0,
            })
        }
    };

    let ledger: Vec<(Uuid, String, i32, String, Option<String>, chrono::DateTime<chrono::Utc>)> =
        sqlx::query_as(
            r#"SELECT id, kind, amount_cents, currency, description, created_at
               FROM billing_ledger WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50"#,
        )
        .bind(uid)
        .fetch_all(&state.pool)
        .await
        .unwrap_or_default();

    let entries: Vec<serde_json::Value> = ledger
        .into_iter()
        .map(|(id, kind, amount_cents, currency, description, created_at)| {
            json!({
                "id": id.to_string(),
                "kind": kind,
                "amount_cents": amount_cents,
                "currency": currency,
                "description": description,
                "created_at": created_at,
            })
        })
        .collect();

    HttpResponse::Ok().json(json!({
        "account": account,
        "ledger": entries,
        "checkout_providers": payment_providers_configured(),
    }))
}

#[derive(Deserialize)]
pub struct CheckoutBody {
    pub plan: Option<String>,
    pub provider: Option<String>,
}

fn plan_stripe_price_id(plan: &str) -> Option<String> {
    let key = match plan {
        "pro" => "STRIPE_PRICE_PRO",
        "team" => "STRIPE_PRICE_TEAM",
        "enterprise" => "STRIPE_PRICE_ENTERPRISE",
        _ => return None,
    };
    std::env::var(key).ok().filter(|s| !s.is_empty())
}

fn plan_yookassa_amount_rub(plan: &str) -> Option<&'static str> {
    match plan {
        "pro" => Some("990.00"),
        "team" => Some("4990.00"),
        "enterprise" => None,
        _ => None,
    }
}

fn checkout_urls() -> (String, String) {
    let base = std::env::var("APP_PUBLIC_URL")
        .unwrap_or_else(|_| "http://localhost:5173".to_string())
        .trim_end_matches('/')
        .to_string();
    let success = std::env::var("STRIPE_CHECKOUT_SUCCESS_URL")
        .unwrap_or_else(|_| format!("{}/dashboard/billing?paid=1", base));
    let cancel = std::env::var("STRIPE_CHECKOUT_CANCEL_URL")
        .unwrap_or_else(|_| format!("{}/dashboard/billing?cancel=1", base));
    (success, cancel)
}

pub async fn post_checkout(state: web::Data<AppState>, req: HttpRequest, body: web::Json<CheckoutBody>) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let plan = body.plan.as_deref().unwrap_or("pro");
    if !matches!(plan, "pro" | "team" | "enterprise") {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "invalid plan".into(),
        });
    }

    let want_yk = body
        .provider
        .as_deref()
        .map(|p| p.eq_ignore_ascii_case("yookassa") || p.eq_ignore_ascii_case("yukassa"))
        .unwrap_or(false);

    let stripe_key = std::env::var("STRIPE_SECRET_KEY").ok().filter(|s| !s.is_empty());
    let yk_shop = std::env::var("YOOKASSA_SHOP_ID").ok().filter(|s| !s.is_empty());
    let yk_secret = std::env::var("YOOKASSA_SECRET_KEY").ok().filter(|s| !s.is_empty());

    if stripe_key.is_none() && (yk_shop.is_none() || yk_secret.is_none()) {
        let _ = sqlx::query(
            r#"INSERT INTO billing_accounts (user_id, plan, status)
               VALUES ($1, $2, 'active')
               ON CONFLICT (user_id) DO UPDATE SET plan = EXCLUDED.plan, status = 'active', updated_at = now()"#,
        )
        .bind(uid)
        .bind(plan)
        .execute(&state.pool)
        .await;
        let roza_url = std::env::var("ROZA_PUBLIC_URL")
            .unwrap_or_else(|_| "http://localhost:5180".to_string())
            .trim_end_matches('/')
            .to_string();
        return HttpResponse::Ok().json(json!({
            "mode": "demo",
            "message": "Демо-оплата: план активирован без платёжного провайдера.",
            "plan": plan,
            "checkout_url": format!("{}/account?billing_demo=1&plan={}", roza_url, plan),
        }));
    }

    if want_yk || (stripe_key.is_none() && yk_shop.is_some()) {
        return yookassa_create_payment(&state, uid, plan).await;
    }

    let sk = match stripe_key {
        Some(s) => s,
        None => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "Stripe не настроен — укажите STRIPE_SECRET_KEY или выберите ЮKassa".into(),
            });
        }
    };

    let price_id = match plan_stripe_price_id(plan) {
        Some(p) => p,
        None => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: format!(
                    "Нет Price ID для плана {} (env STRIPE_PRICE_{})",
                    plan,
                    plan.to_uppercase()
                ),
            });
        }
    };

    let (success_url, cancel_url) = checkout_urls();
    let client = &state.http_client;
    let uid_str = uid.to_string();
    let form = vec![
        ("mode", "subscription"),
        ("success_url", success_url.as_str()),
        ("cancel_url", cancel_url.as_str()),
        ("metadata[user_id]", uid_str.as_str()),
        ("metadata[plan]", plan),
        ("line_items[0][price]", price_id.as_str()),
        ("line_items[0][quantity]", "1"),
    ];

    let resp = match client
        .post("https://api.stripe.com/v1/checkout/sessions")
        .header("Authorization", format!("Bearer {}", sk))
        .form(&form)
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            log::error!("stripe checkout http: {}", e);
            return HttpResponse::BadGateway().json(ErrorResponse {
                error: "stripe request failed".into(),
            });
        }
    };

    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        log::warn!("stripe checkout error: {} {}", status, text);
        return HttpResponse::BadGateway().json(ErrorResponse {
            error: format!("stripe error: {}", status),
        });
    }

    let v: Value = match serde_json::from_str(&text) {
        Ok(j) => j,
        Err(_) => {
            return HttpResponse::BadGateway().json(ErrorResponse {
                error: "stripe invalid json".into(),
            });
        }
    };

    let url = v.get("url").and_then(|x| x.as_str()).unwrap_or("");
    let session_id = v.get("id").and_then(|x| x.as_str()).unwrap_or("");
    if url.is_empty() {
        return HttpResponse::BadGateway().json(ErrorResponse {
            error: "stripe session without url".into(),
        });
    }

    let _ = sqlx::query(
        r#"INSERT INTO billing_accounts (user_id, plan, status, updated_at)
           VALUES ($1, $2, 'trialing', now())
           ON CONFLICT (user_id) DO UPDATE SET plan = $2, status = 'trialing', updated_at = now()"#,
    )
    .bind(uid)
    .bind(plan)
    .execute(&state.pool)
    .await;

    HttpResponse::Ok().json(json!({
        "mode": "stripe",
        "checkout_url": url,
        "session_id": session_id,
        "plan": plan,
    }))
}

async fn yookassa_create_payment(state: &web::Data<AppState>, uid: Uuid, plan: &str) -> HttpResponse {
    let shop_id = match std::env::var("YOOKASSA_SHOP_ID").ok().filter(|s| !s.is_empty()) {
        Some(s) => s,
        None => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "YOOKASSA_SHOP_ID not set".into(),
            });
        }
    };
    let secret = match std::env::var("YOOKASSA_SECRET_KEY").ok().filter(|s| !s.is_empty()) {
        Some(s) => s,
        None => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "YOOKASSA_SECRET_KEY not set".into(),
            });
        }
    };

    let amount = match plan_yookassa_amount_rub(plan) {
        Some(a) => a,
        None => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "Для enterprise ЮKassa укажите сумму вручную (пока не автоматизировано)".into(),
            });
        }
    };

    let (success_url, _) = checkout_urls();
    let idem = Uuid::new_v4().to_string();
    let body = json!({
        "amount": { "value": amount, "currency": "RUB" },
        "capture": true,
        "confirmation": { "type": "redirect", "return_url": success_url },
        "description": format!("NEXUS plan {}", plan),
        "metadata": {
            "user_id": uid.to_string(),
            "plan": plan,
        }
    });

    let resp = match state
        .http_client
        .post("https://api.yookassa.ru/v3/payments")
        .basic_auth(&shop_id, Some(&secret))
        .header("Idempotence-Key", &idem)
        .json(&body)
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            log::error!("yookassa create: {}", e);
            return HttpResponse::BadGateway().json(ErrorResponse {
                error: "yookassa request failed".into(),
            });
        }
    };

    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        log::warn!("yookassa error: {} {}", status, text);
        return HttpResponse::BadGateway().json(ErrorResponse {
            error: format!("yookassa: {}", status),
        });
    }

    let v: Value = match serde_json::from_str(&text) {
        Ok(j) => j,
        Err(_) => {
            return HttpResponse::BadGateway().json(ErrorResponse {
                error: "yookassa invalid json".into(),
            });
        }
    };

    let confirm = v
        .pointer("/confirmation/confirmation_url")
        .and_then(|x| x.as_str())
        .unwrap_or("");
    if confirm.is_empty() {
        return HttpResponse::BadGateway().json(ErrorResponse {
            error: "yookassa: no confirmation_url".into(),
        });
    }

    let payment_id = v.get("id").and_then(|x| x.as_str()).unwrap_or("");

    let _ = sqlx::query(
        r#"INSERT INTO billing_accounts (user_id, plan, status, updated_at)
           VALUES ($1, $2, 'trialing', now())
           ON CONFLICT (user_id) DO UPDATE SET plan = $2, status = 'trialing', updated_at = now()"#,
    )
    .bind(uid)
    .bind(plan)
    .execute(&state.pool)
    .await;

    HttpResponse::Ok().json(json!({
        "mode": "yookassa",
        "checkout_url": confirm,
        "payment_id": payment_id,
        "plan": plan,
    }))
}

fn stripe_wh_secret() -> Option<String> {
    std::env::var("STRIPE_WEBHOOK_SECRET")
        .ok()
        .filter(|s| !s.is_empty())
}

fn verify_stripe_signature(payload: &[u8], sig_header: &str, whsec: &str) -> bool {
    let key_b64 = whsec.strip_prefix("whsec_").unwrap_or(whsec);
    let key_bytes = match STANDARD.decode(key_b64) {
        Ok(b) => b,
        Err(_) => return false,
    };
    let mut ts: Option<&str> = None;
    let mut v1_sigs: Vec<&str> = Vec::new();
    for part in sig_header.split(',') {
        let mut it = part.trim().splitn(2, '=');
        let k = it.next().unwrap_or("");
        let v = it.next().unwrap_or("");
        match k {
            "t" => ts = Some(v),
            "v1" => v1_sigs.push(v),
            _ => {}
        }
    }
    let t = match ts {
        Some(t) => t,
        None => return false,
    };
    let signed = format!("{}.{}", t, String::from_utf8_lossy(payload));
    let Ok(mut mac) = HmacSha256::new_from_slice(&key_bytes) else {
        return false;
    };
    mac.update(signed.as_bytes());
    let expected = mac.finalize().into_bytes();
    let expected_hex = hex::encode(expected);
    v1_sigs
        .iter()
        .any(|s| s.eq_ignore_ascii_case(&expected_hex))
}

async fn apply_stripe_checkout_completed(pool: &sqlx::PgPool, session: &Value) {
    let meta = session.get("metadata").cloned().unwrap_or(json!({}));
    let user_id_str = meta.get("user_id").and_then(|x| x.as_str()).unwrap_or("");
    let plan = meta.get("plan").and_then(|x| x.as_str()).unwrap_or("pro");
    let Ok(uid) = Uuid::parse_str(user_id_str) else {
        log::warn!("stripe webhook: bad user_id in metadata");
        return;
    };
    let customer = session
        .get("customer")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    let sub = session
        .get("subscription")
        .and_then(|x| x.as_str())
        .map(|s| s.to_string());

    let _ = sqlx::query(
        r#"INSERT INTO billing_accounts (user_id, plan, status, stripe_customer_id, stripe_subscription_id, updated_at)
           VALUES ($1, $2, 'active', NULLIF($3, ''), NULLIF($4, ''), now())
           ON CONFLICT (user_id) DO UPDATE SET
             plan = EXCLUDED.plan,
             status = 'active',
             stripe_customer_id = COALESCE(NULLIF(EXCLUDED.stripe_customer_id, ''), billing_accounts.stripe_customer_id),
             stripe_subscription_id = COALESCE(NULLIF(EXCLUDED.stripe_subscription_id, ''), billing_accounts.stripe_subscription_id),
             updated_at = now()"#,
    )
    .bind(uid)
    .bind(plan)
    .bind(&customer)
    .bind(sub.as_deref().unwrap_or(""))
    .execute(pool)
    .await;

    let _ = sqlx::query(
        r#"INSERT INTO billing_ledger (user_id, kind, amount_cents, currency, description, meta)
           VALUES ($1, 'subscription', 0, 'usd', $2, $3)"#,
    )
    .bind(uid)
    .bind(format!("Stripe checkout completed, plan {}", plan))
    .bind(session.clone())
    .execute(pool)
    .await;
}

pub async fn stripe_webhook(state: web::Data<AppState>, req: HttpRequest, body: web::Bytes) -> impl Responder {
    let secret = match stripe_wh_secret() {
        Some(s) => s,
        None => {
            log::info!("stripe webhook: STRIPE_WEBHOOK_SECRET not set, skipping verify");
            return HttpResponse::Ok().json(json!({ "received": true, "verified": false }));
        }
    };
    let sig = match req.headers().get("Stripe-Signature").and_then(|h| h.to_str().ok()) {
        Some(s) => s,
        None => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "missing Stripe-Signature".into(),
            });
        }
    };
    if !verify_stripe_signature(&body, sig, &secret) {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "invalid signature".into(),
        });
    }

    let payload: Value = match serde_json::from_slice(&body) {
        Ok(v) => v,
        Err(_) => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "invalid json".into(),
            });
        }
    };

    let typ = payload.get("type").and_then(|x| x.as_str()).unwrap_or("");
    if typ == "checkout.session.completed" {
        if let Some(session) = payload.pointer("/data/object") {
            apply_stripe_checkout_completed(&state.pool, session).await;
        }
    }

    HttpResponse::Ok().json(json!({ "received": true, "verified": true }))
}

pub async fn yookassa_webhook(state: web::Data<AppState>, body: web::Bytes) -> impl Responder {
    let v: Value = match serde_json::from_slice(&body) {
        Ok(j) => j,
        Err(_) => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "invalid json".into(),
            });
        }
    };

    let event = v.get("event").and_then(|x| x.as_str()).unwrap_or("");
    let obj = v.get("object").cloned().unwrap_or(json!({}));
    let payment_id = obj.get("id").and_then(|x| x.as_str()).unwrap_or("");

    if payment_id.is_empty() || event != "payment.succeeded" {
        return HttpResponse::Ok().json(json!({ "received": true, "handled": false }));
    }

    let shop_id = match std::env::var("YOOKASSA_SHOP_ID").ok().filter(|s| !s.is_empty()) {
        Some(s) => s,
        None => return HttpResponse::ServiceUnavailable().json(ErrorResponse {
            error: "yookassa not configured".into(),
        }),
    };
    let secret = match std::env::var("YOOKASSA_SECRET_KEY").ok().filter(|s| !s.is_empty()) {
        Some(s) => s,
        None => return HttpResponse::ServiceUnavailable().json(ErrorResponse {
            error: "yookassa not configured".into(),
        }),
    };

    let verify_url = format!("https://api.yookassa.ru/v3/payments/{}", payment_id);
    let resp = match state
        .http_client
        .get(&verify_url)
        .basic_auth(&shop_id, Some(&secret))
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            log::error!("yookassa verify: {}", e);
            return HttpResponse::BadGateway().json(ErrorResponse {
                error: "verify failed".into(),
            });
        }
    };

    if !resp.status().is_success() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "payment not confirmed".into(),
        });
    }

    let pay: Value = match resp.json().await {
        Ok(j) => j,
        Err(_) => {
            return HttpResponse::BadGateway().json(ErrorResponse {
                error: "yookassa verify json".into(),
            });
        }
    };

    if pay.get("status").and_then(|x| x.as_str()) != Some("succeeded") {
        return HttpResponse::Ok().json(json!({ "received": true, "handled": false }));
    }

    let meta = pay.get("metadata").cloned().unwrap_or(json!({}));
    let user_id_str = meta.get("user_id").and_then(|x| x.as_str()).unwrap_or("");
    let plan = meta.get("plan").and_then(|x| x.as_str()).unwrap_or("pro");
    let Ok(uid) = Uuid::parse_str(user_id_str) else {
        log::warn!("yookassa: bad user_id");
        return HttpResponse::Ok().json(json!({ "received": true, "handled": false }));
    };

    let amount_str = pay
        .pointer("/amount/value")
        .and_then(|x| x.as_str())
        .unwrap_or("0");
    let amount_cents = (amount_str.parse::<f64>().unwrap_or(0.0) * 100.0).round() as i32;

    let _ = sqlx::query(
        r#"INSERT INTO billing_accounts (user_id, plan, status, updated_at)
           VALUES ($1, $2, 'active', now())
           ON CONFLICT (user_id) DO UPDATE SET plan = $2, status = 'active', updated_at = now()"#,
    )
    .bind(uid)
    .bind(plan)
    .execute(&state.pool)
    .await;

    let _ = sqlx::query(
        r#"INSERT INTO billing_ledger (user_id, kind, amount_cents, currency, description, meta)
           VALUES ($1, 'charge', $2, 'rub', $3, $4)"#,
    )
    .bind(uid)
    .bind(amount_cents)
    .bind(format!("ЮKassa payment {}", payment_id))
    .bind(pay.clone())
    .execute(&state.pool)
    .await;

    HttpResponse::Ok().json(json!({ "received": true, "handled": true }))
}

pub async fn admin_billing_summary(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let secret = match jwt_secret() {
        Ok(s) => s,
        Err(e) => return e,
    };
    let uid = match get_user_id_from_token(&req, &secret) {
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

    let plans: Vec<(String, i64)> = sqlx::query_as(
        r#"SELECT plan, COUNT(*)::bigint FROM billing_accounts GROUP BY plan ORDER BY plan"#,
    )
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    let revenue: Option<(i64,)> = sqlx::query_as(
        r#"SELECT COALESCE(SUM(amount_cents), 0)::bigint FROM billing_ledger WHERE kind IN ('charge', 'subscription')"#,
    )
    .fetch_one(&state.pool)
    .await
    .ok();

    HttpResponse::Ok().json(json!({
        "plans": plans.into_iter().map(|(p, c)| json!({"plan": p, "accounts": c})).collect::<Vec<_>>(),
        "ledger_sum_cents": revenue.map(|r| r.0).unwrap_or(0),
        "checkout_providers": payment_providers_configured(),
    }))
}
