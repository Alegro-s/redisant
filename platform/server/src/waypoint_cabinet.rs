
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{get_user_id_from_token, AppState, ErrorResponse};

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

pub(crate) async fn billing_plan(pool: &PgPool, user_id: Uuid) -> String {
    sqlx::query_scalar::<_, String>("SELECT plan FROM billing_accounts WHERE user_id = $1")
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .ok()
        .flatten()
        .unwrap_or_else(|| "free".into())
}

fn is_pro_plan(plan: &str) -> bool {
    matches!(plan, "pro" | "team" | "enterprise")
}

pub fn ai_daily_limit(plan: &str, persona_developer: bool) -> i32 {
    let pro = is_pro_plan(plan);
    if pro {
        if persona_developer {
            std::env::var("AI_LIMIT_PRO_DEVELOPER")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(500)
        } else {
            std::env::var("AI_LIMIT_PRO_BUSINESS")
                .ok()
                .and_then(|s| s.parse().ok())
                .unwrap_or(500)
        }
    } else if persona_developer {
        std::env::var("AI_LIMIT_FREE_DEVELOPER")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(40)
    } else {
        std::env::var("AI_LIMIT_FREE_BUSINESS")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(25)
    }
}

fn utc_today() -> NaiveDate {
    chrono::Utc::now().date_naive()
}

pub async fn consume_ai_quota(
    pool: &PgPool,
    user_id: Uuid,
    persona: &str,
    limit: i32,
) -> Result<Option<i32>, sqlx::Error> {
    let row: Option<(i32,)> = sqlx::query_as(
        r#"
        INSERT INTO ai_usage_daily (user_id, usage_date, persona, message_count)
        VALUES ($1, (timezone('utc', now()))::date, $2, 1)
        ON CONFLICT (user_id, usage_date, persona)
        DO UPDATE SET
            message_count = ai_usage_daily.message_count + 1,
            updated_at = now()
        WHERE ai_usage_daily.message_count < $3
        RETURNING message_count
        "#,
    )
    .bind(user_id)
    .bind(persona)
    .bind(limit)
    .fetch_optional(pool)
    .await?;

    Ok(row.map(|(c,)| c))
}

pub async fn release_ai_quota(pool: &PgPool, user_id: Uuid, persona: &str) {
    let _ = sqlx::query(
        r#"UPDATE ai_usage_daily SET
            message_count = GREATEST(0, message_count - 1),
            updated_at = now()
           WHERE user_id = $1
             AND usage_date = (timezone('utc', now()))::date
             AND persona = $2
             AND message_count > 0"#,
    )
    .bind(user_id)
    .bind(persona)
    .execute(pool)
    .await;
}

async fn quota_used(pool: &PgPool, user_id: Uuid, persona: &str) -> i32 {
    sqlx::query_scalar::<_, Option<i32>>(
        r#"SELECT message_count FROM ai_usage_daily
           WHERE user_id = $1 AND usage_date = (timezone('utc', now()))::date AND persona = $2"#,
    )
    .bind(user_id)
    .bind(persona)
    .fetch_optional(pool)
    .await
    .ok()
    .flatten()
    .flatten()
    .unwrap_or(0)
}

pub async fn get_ai_quota(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let plan = billing_plan(&state.pool, uid).await;
    let lim_b = ai_daily_limit(&plan, false);
    let lim_d = ai_daily_limit(&plan, true);
    let used_b = quota_used(&state.pool, uid, "business").await;
    let used_d = quota_used(&state.pool, uid, "developer").await;

    HttpResponse::Ok().json(json!({
        "plan": plan,
        "utc_date": utc_today().to_string(),
        "business": { "used": used_b, "limit": lim_b },
        "developer": { "used": used_d, "limit": lim_d },
    }))
}


#[derive(Serialize, sqlx::FromRow)]
struct VoucherRow {
    id: Uuid,
    user_id: Uuid,
    code: String,
    campaign: String,
    redeem_limit: i32,
    redeemed: i32,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Deserialize)]
pub struct VoucherCreateBody {
    pub code: String,
    #[serde(default)]
    pub campaign: String,
    #[serde(default)]
    pub redeem_limit: i32,
    #[serde(default)]
    pub redeemed: i32,
}

#[derive(Deserialize, Default)]
pub struct VoucherPatchBody {
    pub code: Option<String>,
    pub campaign: Option<String>,
    pub redeem_limit: Option<i32>,
    pub redeemed: Option<i32>,
}

pub async fn list_vouchers(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let rows: Vec<VoucherRow> = match sqlx::query_as(
        r#"SELECT id, user_id, code, campaign, redeem_limit, redeemed, created_at, updated_at
           FROM waypoint_vouchers WHERE user_id = $1 ORDER BY created_at DESC"#,
    )
    .bind(uid)
    .fetch_all(&state.pool)
    .await
    {
        Ok(r) => r,
        Err(e) => {
            log::error!("list_vouchers: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            });
        }
    };
    HttpResponse::Ok().json(json!({ "items": rows }))
}

pub async fn create_voucher(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<VoucherCreateBody>,
) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let code = body.code.trim().to_uppercase();
    if code.len() < 2 || code.len() > 64 {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "code length must be 2..64".into(),
        });
    }
    if body.redeemed < 0 || body.redeem_limit < 0 {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "redeemed and redeem_limit must be >= 0".into(),
        });
    }
    let row: Result<VoucherRow, sqlx::Error> = sqlx::query_as(
        r#"INSERT INTO waypoint_vouchers (user_id, code, campaign, redeem_limit, redeemed)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING id, user_id, code, campaign, redeem_limit, redeemed, created_at, updated_at"#,
    )
    .bind(uid)
    .bind(&code)
    .bind(body.campaign.trim())
    .bind(body.redeem_limit)
    .bind(body.redeemed)
    .fetch_one(&state.pool)
    .await;

    match row {
        Ok(r) => HttpResponse::Created().json(r),
        Err(sqlx::Error::Database(d)) if d.is_unique_violation() => {
            HttpResponse::Conflict().json(ErrorResponse {
                error: "code already exists".into(),
            })
        }
        Err(e) => {
            log::error!("create_voucher: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}

pub async fn patch_voucher(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
    body: web::Json<VoucherPatchBody>,
) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let id = path.into_inner();

    let cur: Option<VoucherRow> = match sqlx::query_as(
        r#"SELECT id, user_id, code, campaign, redeem_limit, redeemed, created_at, updated_at
           FROM waypoint_vouchers WHERE id = $1 AND user_id = $2"#,
    )
    .bind(id)
    .bind(uid)
    .fetch_optional(&state.pool)
    .await
    {
        Ok(r) => r,
        Err(e) => {
            log::error!("patch_voucher fetch: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            });
        }
    };
    let Some(mut row) = cur else {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "not found".into(),
        });
    };

    if let Some(ref c) = body.code {
        let c = c.trim().to_uppercase();
        if c.len() < 2 || c.len() > 64 {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "code length must be 2..64".into(),
            });
        }
        row.code = c;
    }
    if let Some(ref c) = body.campaign {
        row.campaign = c.trim().to_string();
    }
    if let Some(l) = body.redeem_limit {
        if l < 0 {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "redeem_limit must be >= 0".into(),
            });
        }
        row.redeem_limit = l;
    }
    if let Some(r) = body.redeemed {
        if r < 0 {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "redeemed must be >= 0".into(),
            });
        }
        row.redeemed = r;
    }

    let updated: Result<VoucherRow, sqlx::Error> = sqlx::query_as(
        r#"UPDATE waypoint_vouchers SET
            code = $3, campaign = $4, redeem_limit = $5, redeemed = $6, updated_at = now()
           WHERE id = $1 AND user_id = $2
           RETURNING id, user_id, code, campaign, redeem_limit, redeemed, created_at, updated_at"#,
    )
    .bind(id)
    .bind(uid)
    .bind(&row.code)
    .bind(&row.campaign)
    .bind(row.redeem_limit)
    .bind(row.redeemed)
    .fetch_one(&state.pool)
    .await;

    match updated {
        Ok(r) => HttpResponse::Ok().json(r),
        Err(sqlx::Error::Database(d)) if d.is_unique_violation() => {
            HttpResponse::Conflict().json(ErrorResponse {
                error: "code already exists".into(),
            })
        }
        Err(e) => {
            log::error!("patch_voucher: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}

pub async fn delete_voucher(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let id = path.into_inner();
    let res = sqlx::query("DELETE FROM waypoint_vouchers WHERE id = $1 AND user_id = $2")
        .bind(id)
        .bind(uid)
        .execute(&state.pool)
        .await;
    match res {
        Ok(r) if r.rows_affected() > 0 => HttpResponse::Ok().json(json!({ "ok": true })),
        Ok(_) => HttpResponse::NotFound().json(ErrorResponse {
            error: "not found".into(),
        }),
        Err(e) => {
            log::error!("delete_voucher: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}


#[derive(Serialize, sqlx::FromRow)]
struct ShipmentRow {
    id: Uuid,
    user_id: Uuid,
    external_ref: String,
    route: String,
    status: String,
    carrier: String,
    meta: Value,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Deserialize)]
pub struct ShipmentCreateBody {
    #[serde(default)]
    pub external_ref: String,
    #[serde(default)]
    pub route: String,
    #[serde(default)]
    pub status: String,
    #[serde(default)]
    pub carrier: String,
    #[serde(default)]
    pub meta: Value,
}

#[derive(Deserialize, Default)]
pub struct ShipmentPatchBody {
    pub external_ref: Option<String>,
    pub route: Option<String>,
    pub status: Option<String>,
    pub carrier: Option<String>,
    pub meta: Option<Value>,
}

pub async fn list_shipments(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let rows: Vec<ShipmentRow> = match sqlx::query_as(
        r#"SELECT id, user_id, external_ref, route, status, carrier, meta, created_at, updated_at
           FROM waypoint_shipments WHERE user_id = $1 ORDER BY created_at DESC"#,
    )
    .bind(uid)
    .fetch_all(&state.pool)
    .await
    {
        Ok(r) => r,
        Err(e) => {
            log::error!("list_shipments: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            });
        }
    };
    HttpResponse::Ok().json(json!({ "items": rows }))
}

pub async fn create_shipment(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<ShipmentCreateBody>,
) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let meta = if body.meta.is_null() {
        json!({})
    } else {
        body.meta.clone()
    };
    let row: Result<ShipmentRow, sqlx::Error> = sqlx::query_as(
        r#"INSERT INTO waypoint_shipments (user_id, external_ref, route, status, carrier, meta)
           VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING id, user_id, external_ref, route, status, carrier, meta, created_at, updated_at"#,
    )
    .bind(uid)
    .bind(body.external_ref.trim())
    .bind(body.route.trim())
    .bind(body.status.trim())
    .bind(body.carrier.trim())
    .bind(meta)
    .fetch_one(&state.pool)
    .await;

    match row {
        Ok(r) => HttpResponse::Created().json(r),
        Err(e) => {
            log::error!("create_shipment: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}

pub async fn patch_shipment(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
    body: web::Json<ShipmentPatchBody>,
) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let id = path.into_inner();

    let cur: Option<ShipmentRow> = match sqlx::query_as(
        r#"SELECT id, user_id, external_ref, route, status, carrier, meta, created_at, updated_at
           FROM waypoint_shipments WHERE id = $1 AND user_id = $2"#,
    )
    .bind(id)
    .bind(uid)
    .fetch_optional(&state.pool)
    .await
    {
        Ok(r) => r,
        Err(e) => {
            log::error!("patch_shipment fetch: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            });
        }
    };
    let Some(mut row) = cur else {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "not found".into(),
        });
    };

    if let Some(ref s) = body.external_ref {
        row.external_ref = s.trim().to_string();
    }
    if let Some(ref s) = body.route {
        row.route = s.trim().to_string();
    }
    if let Some(ref s) = body.status {
        row.status = s.trim().to_string();
    }
    if let Some(ref s) = body.carrier {
        row.carrier = s.trim().to_string();
    }
    if let Some(m) = &body.meta {
        if !m.is_null() {
            row.meta = m.clone();
        }
    }

    let updated: Result<ShipmentRow, sqlx::Error> = sqlx::query_as(
        r#"UPDATE waypoint_shipments SET
            external_ref = $3, route = $4, status = $5, carrier = $6, meta = $7, updated_at = now()
           WHERE id = $1 AND user_id = $2
           RETURNING id, user_id, external_ref, route, status, carrier, meta, created_at, updated_at"#,
    )
    .bind(id)
    .bind(uid)
    .bind(&row.external_ref)
    .bind(&row.route)
    .bind(&row.status)
    .bind(&row.carrier)
    .bind(&row.meta)
    .fetch_one(&state.pool)
    .await;

    match updated {
        Ok(r) => HttpResponse::Ok().json(r),
        Err(e) => {
            log::error!("patch_shipment: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}

pub async fn delete_shipment(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    let uid = match auth_uid(&req).await {
        Ok(u) => u,
        Err(e) => return e,
    };
    let id = path.into_inner();
    let res = sqlx::query("DELETE FROM waypoint_shipments WHERE id = $1 AND user_id = $2")
        .bind(id)
        .bind(uid)
        .execute(&state.pool)
        .await;
    match res {
        Ok(r) if r.rows_affected() > 0 => HttpResponse::Ok().json(json!({ "ok": true })),
        Ok(_) => HttpResponse::NotFound().json(ErrorResponse {
            error: "not found".into(),
        }),
        Err(e) => {
            log::error!("delete_shipment: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}
