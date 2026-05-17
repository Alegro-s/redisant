
use actix_multipart::Multipart;
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use futures_util::StreamExt as _;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::types::Json as SqlJson;
use sqlx::{Column, PgPool, Row};
use std::env;
use std::path::PathBuf;
use tokio::fs;
use tokio::io::AsyncWriteExt;
use uuid::Uuid;

use crate::admin_sql;
use crate::{get_user_id_from_token, AppState, ErrorResponse};

const BAAS_MAX_SELECT_ROWS: usize = 500;
const MAX_PG_PARAMS: usize = 16;

fn max_placeholder_index(q: &str) -> Result<usize, &'static str> {
    let mut max_n = 0usize;
    let chars: Vec<char> = q.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        if chars[i] == '$' {
            if i + 1 >= chars.len() || !chars[i + 1].is_ascii_digit() {
                return Err("Invalid placeholder: expected $ followed by digits");
            }
            i += 1;
            let mut n = 0usize;
            while i < chars.len() && chars[i].is_ascii_digit() {
                n = n * 10 + (chars[i] as u8 - b'0') as usize;
                i += 1;
            }
            if n == 0 || n > MAX_PG_PARAMS {
                return Err("Parameter index must be 1..=16");
            }
            max_n = max_n.max(n);
        } else {
            i += 1;
        }
    }
    Ok(max_n)
}

async fn baas_query_with_params(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    q: &str,
    params: &[serde_json::Value],
) -> Result<Vec<sqlx::postgres::PgRow>, sqlx::Error> {
    Ok(match params.len() {
        0 => sqlx::query(q).fetch_all(&mut **tx).await?,
        1 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .fetch_all(&mut **tx)
            .await?,
        2 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .fetch_all(&mut **tx)
            .await?,
        3 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .fetch_all(&mut **tx)
            .await?,
        4 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .fetch_all(&mut **tx)
            .await?,
        5 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .fetch_all(&mut **tx)
            .await?,
        6 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .fetch_all(&mut **tx)
            .await?,
        7 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .fetch_all(&mut **tx)
            .await?,
        8 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .fetch_all(&mut **tx)
            .await?,
        9 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .fetch_all(&mut **tx)
            .await?,
        10 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .fetch_all(&mut **tx)
            .await?,
        11 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .bind(SqlJson(params[10].clone()))
            .fetch_all(&mut **tx)
            .await?,
        12 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .bind(SqlJson(params[10].clone()))
            .bind(SqlJson(params[11].clone()))
            .fetch_all(&mut **tx)
            .await?,
        13 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .bind(SqlJson(params[10].clone()))
            .bind(SqlJson(params[11].clone()))
            .bind(SqlJson(params[12].clone()))
            .fetch_all(&mut **tx)
            .await?,
        14 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .bind(SqlJson(params[10].clone()))
            .bind(SqlJson(params[11].clone()))
            .bind(SqlJson(params[12].clone()))
            .bind(SqlJson(params[13].clone()))
            .fetch_all(&mut **tx)
            .await?,
        15 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .bind(SqlJson(params[10].clone()))
            .bind(SqlJson(params[11].clone()))
            .bind(SqlJson(params[12].clone()))
            .bind(SqlJson(params[13].clone()))
            .bind(SqlJson(params[14].clone()))
            .fetch_all(&mut **tx)
            .await?,
        16 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .bind(SqlJson(params[10].clone()))
            .bind(SqlJson(params[11].clone()))
            .bind(SqlJson(params[12].clone()))
            .bind(SqlJson(params[13].clone()))
            .bind(SqlJson(params[14].clone()))
            .bind(SqlJson(params[15].clone()))
            .fetch_all(&mut **tx)
            .await?,
        _ => unreachable!("length checked against max_placeholder_index"),
    })
}

async fn baas_execute_with_params(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    q: &str,
    params: &[serde_json::Value],
) -> Result<u64, sqlx::Error> {
    let r = match params.len() {
        0 => sqlx::query(q).execute(&mut **tx).await?,
        1 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .execute(&mut **tx)
            .await?,
        2 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .execute(&mut **tx)
            .await?,
        3 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .execute(&mut **tx)
            .await?,
        4 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .execute(&mut **tx)
            .await?,
        5 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .execute(&mut **tx)
            .await?,
        6 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .execute(&mut **tx)
            .await?,
        7 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .execute(&mut **tx)
            .await?,
        8 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .execute(&mut **tx)
            .await?,
        9 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .execute(&mut **tx)
            .await?,
        10 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .execute(&mut **tx)
            .await?,
        11 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .bind(SqlJson(params[10].clone()))
            .execute(&mut **tx)
            .await?,
        12 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .bind(SqlJson(params[10].clone()))
            .bind(SqlJson(params[11].clone()))
            .execute(&mut **tx)
            .await?,
        13 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .bind(SqlJson(params[10].clone()))
            .bind(SqlJson(params[11].clone()))
            .bind(SqlJson(params[12].clone()))
            .execute(&mut **tx)
            .await?,
        14 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .bind(SqlJson(params[10].clone()))
            .bind(SqlJson(params[11].clone()))
            .bind(SqlJson(params[12].clone()))
            .bind(SqlJson(params[13].clone()))
            .execute(&mut **tx)
            .await?,
        15 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .bind(SqlJson(params[10].clone()))
            .bind(SqlJson(params[11].clone()))
            .bind(SqlJson(params[12].clone()))
            .bind(SqlJson(params[13].clone()))
            .bind(SqlJson(params[14].clone()))
            .execute(&mut **tx)
            .await?,
        16 => sqlx::query(q)
            .bind(SqlJson(params[0].clone()))
            .bind(SqlJson(params[1].clone()))
            .bind(SqlJson(params[2].clone()))
            .bind(SqlJson(params[3].clone()))
            .bind(SqlJson(params[4].clone()))
            .bind(SqlJson(params[5].clone()))
            .bind(SqlJson(params[6].clone()))
            .bind(SqlJson(params[7].clone()))
            .bind(SqlJson(params[8].clone()))
            .bind(SqlJson(params[9].clone()))
            .bind(SqlJson(params[10].clone()))
            .bind(SqlJson(params[11].clone()))
            .bind(SqlJson(params[12].clone()))
            .bind(SqlJson(params[13].clone()))
            .bind(SqlJson(params[14].clone()))
            .bind(SqlJson(params[15].clone()))
            .execute(&mut **tx)
            .await?,
        _ => unreachable!("length checked against max_placeholder_index"),
    };
    Ok(r.rows_affected())
}

pub(crate) async fn emit_wm_baas_event(
    state: &AppState,
    pool: &PgPool,
    user_id: Uuid,
    table: &str,
    op: &str,
    row: &Value,
) {
    if let Some(pm) = &state.prometheus {
        let _ = pm.baas_rest_events.with_label_values(&[op]).inc();
    }
    let payload = json!({
        "u": user_id.to_string(),
        "t": table,
        "o": op,
        "row": row,
    });
    let mut s = payload.to_string();
    if s.len() > 7800 {
        s = json!({
            "u": user_id.to_string(),
            "t": table,
            "o": op,
            "id": row.get("id"),
        })
        .to_string();
    }
    let _ = sqlx::query("SELECT pg_notify('wm_baas', $1)")
        .bind(&s)
        .execute(pool)
        .await;
}

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

fn baas_globally_disabled() -> bool {
    matches!(
        env::var("WM_BAAS_DISABLED").as_deref(),
        Ok("1") | Ok("true") | Ok("yes")
    )
}

fn storage_root() -> PathBuf {
    PathBuf::from(
        env::var("WM_BAAS_STORAGE_ROOT").unwrap_or_else(|_| "./uploads/baas-storage".into()),
    )
}

fn max_object_bytes() -> usize {
    env::var("WM_BAAS_MAX_OBJECT_MB")
        .ok()
        .and_then(|s| s.parse::<usize>().ok())
        .unwrap_or(50)
        * 1024
        * 1024
}

fn valid_rel_identifier(name: &str) -> bool {
    let mut it = name.chars();
    match it.next() {
        Some(c) if c.is_ascii_lowercase() => {}
        _ => return false,
    }
    name.len() <= 63
        && name
            .chars()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_')
}

fn forbid_cross_tenant_fragments(q: &str) -> Result<(), &'static str> {
    let lower = q.to_lowercase();
    let stripped = admin_sql::strip_sql_comments(&lower);
    for needle in [
        "public.",
        "\"public\"",
        "information_schema",
        "pg_catalog",
        "pg_temp.",
        "pg_toast",
        "dblink",
        "lo_import",
        "lo_export",
        "copy (",
        "copy(",
        "execute ",
        "prepare ",
    ] {
        if stripped.contains(needle) {
            return Err("Query references forbidden schemas or operations");
        }
    }
    Ok(())
}

fn baas_allow_write(cfg: &crate::config::RuntimeConfig) -> bool {
    match env::var("WM_BAAS_SQL_WRITE") {
        Ok(v) => v == "1" || v.eq_ignore_ascii_case("true"),
        Err(_) => cfg.admin_allow_sql_write,
    }
}

async fn ensure_user_schema(pool: &PgPool, user_id: Uuid) -> Result<String, sqlx::Error> {
    let row: Option<(String,)> =
        sqlx::query_as("SELECT schema_name FROM wm_baas_user_schema WHERE user_id = $1")
            .bind(user_id)
            .fetch_optional(pool)
            .await?;
    if let Some((name,)) = row {
        return Ok(name);
    }
    let hex = user_id.as_simple().to_string();
    let schema = format!("wm_u_{hex}");
    let mut tx = pool.begin().await?;
    let create = format!(r#"CREATE SCHEMA IF NOT EXISTS "{}""#, schema);
    sqlx::query(&create).execute(&mut *tx).await?;
    sqlx::query(
        "INSERT INTO wm_baas_user_schema (user_id, schema_name) VALUES ($1, $2) ON CONFLICT (user_id) DO NOTHING",
    )
    .bind(user_id)
    .bind(&schema)
    .execute(&mut *tx)
    .await?;
    tx.commit().await?;
    let (name,): (String,) =
        sqlx::query_as("SELECT schema_name FROM wm_baas_user_schema WHERE user_id = $1")
            .bind(user_id)
            .fetch_one(pool)
            .await?;
    Ok(name)
}

fn quote_ident(s: &str) -> String {
    format!("\"{}\"", s.replace('"', "\"\""))
}

pub async fn get_schema(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    match ensure_user_schema(&state.pool, uid).await {
        Ok(schema) => HttpResponse::Ok().json(json!({ "schema_name": schema })),
        Err(e) => {
            log::error!("baas ensure schema: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "schema error".into(),
            })
        }
    }
}

#[derive(Deserialize)]
pub struct BaasSqlBody {
    query: String,
}

#[derive(Deserialize)]
pub struct BaasSqlParamBody {
    query: String,
    #[serde(default)]
    params: Vec<serde_json::Value>,
}

#[derive(Serialize)]
struct DbQueryResponse {
    columns: Vec<String>,
    rows: Vec<Value>,
}

pub async fn post_sql(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<BaasSqlBody>,
) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let schema = match ensure_user_schema(&state.pool, uid).await {
        Ok(s) => s,
        Err(e) => {
            log::error!("baas schema: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "schema error".into(),
            });
        }
    };

    let q = body.query.trim();
    if let Err(msg) = forbid_cross_tenant_fragments(q) {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: msg.into(),
        });
    }

    let allow_raw = state.config.admin_allow_raw_sql;
    let allow_write = baas_allow_write(&state.config);
    let start = admin_sql::normalized_start(q);
    let is_read = start.starts_with("select")
        || start.starts_with("with")
        || start.starts_with("explain");

    if start.starts_with("set ")
        || start.starts_with("begin")
        || start.starts_with("commit")
        || start.starts_with("rollback")
        || start.starts_with("listen")
        || start.starts_with("notify")
        || start.starts_with("reset ")
    {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "This statement class is not allowed in BaaS SQL".into(),
        });
    }

    if is_read {
        if let Err(msg) = admin_sql::validate_admin_query(q, true, allow_raw, false) {
            return HttpResponse::Forbidden().json(ErrorResponse {
                error: msg.into(),
            });
        }
    } else if let Err(msg) = admin_sql::validate_admin_query(q, false, allow_raw, allow_write) {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: msg.into(),
        });
    }

    let set_path = format!(
        "SET LOCAL search_path = {}, pg_temp",
        quote_ident(&schema)
    );

    let mut tx = match state.pool.begin().await {
        Ok(t) => t,
        Err(e) => {
            log::error!("baas tx: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            });
        }
    };

    if sqlx::query(&set_path).execute(&mut *tx).await.is_err() {
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "failed to set search_path".into(),
        });
    }
    let _ = sqlx::query("SET LOCAL statement_timeout = '8000ms'")
        .execute(&mut *tx)
        .await;

    if is_read {
        match sqlx::query(q).fetch_all(&mut *tx).await {
            Ok(rows) => {
                if rows.len() > BAAS_MAX_SELECT_ROWS {
                    let _ = tx.rollback().await;
                    return HttpResponse::BadRequest().json(ErrorResponse {
                        error: format!("Too many rows (max {})", BAAS_MAX_SELECT_ROWS),
                    });
                }
                if let Err(e) = tx.commit().await {
                    log::error!("baas commit: {}", e);
                    return HttpResponse::InternalServerError().json(ErrorResponse {
                        error: "database error".into(),
                    });
                }
                if rows.is_empty() {
                    return HttpResponse::Ok().json(DbQueryResponse {
                        columns: vec![],
                        rows: vec![],
                    });
                }
                let columns: Vec<String> = rows[0]
                    .columns()
                    .iter()
                    .map(|c| c.name().to_string())
                    .collect();
                let json_rows: Vec<Value> = rows
                    .into_iter()
                    .map(|row| {
                        let mut map = serde_json::Map::new();
                        for col in &columns {
                            let value: Value =
                                row.try_get::<serde_json::Value, _>(col.as_str())
                                    .unwrap_or(Value::Null);
                            map.insert(col.clone(), value);
                        }
                        Value::Object(map)
                    })
                    .collect();
                HttpResponse::Ok().json(DbQueryResponse {
                    columns,
                    rows: json_rows,
                })
            }
            Err(e) => {
                let _ = tx.rollback().await;
                HttpResponse::BadRequest().json(ErrorResponse {
                    error: format!("Query error: {}", e),
                })
            }
        }
    } else {
        match sqlx::query(q).execute(&mut *tx).await {
            Ok(r) => {
                if let Err(e) = tx.commit().await {
                    log::error!("baas commit: {}", e);
                    return HttpResponse::InternalServerError().json(ErrorResponse {
                        error: "database error".into(),
                    });
                }
                HttpResponse::Ok().json(json!({
                    "rows_affected": r.rows_affected(),
                }))
            }
            Err(e) => {
                let _ = tx.rollback().await;
                HttpResponse::BadRequest().json(ErrorResponse {
                    error: format!("Query error: {}", e),
                })
            }
        }
    }
}

pub async fn post_sql_param(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<BaasSqlParamBody>,
) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let schema = match ensure_user_schema(&state.pool, uid).await {
        Ok(s) => s,
        Err(e) => {
            log::error!("baas schema: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "schema error".into(),
            });
        }
    };

    let q = body.query.trim();
    if let Err(msg) = forbid_cross_tenant_fragments(q) {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: msg.into(),
        });
    }

    let max_ph = match max_placeholder_index(q) {
        Ok(n) => n,
        Err(msg) => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: msg.into(),
            })
        }
    };
    if body.params.len() != max_ph {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: format!(
                "params length {} does not match max placeholder index {}",
                body.params.len(),
                max_ph
            ),
        });
    }

    let allow_raw = state.config.admin_allow_raw_sql;
    let allow_write = baas_allow_write(&state.config);
    let start = admin_sql::normalized_start(q);
    let is_read = start.starts_with("select")
        || start.starts_with("with")
        || start.starts_with("explain");

    if start.starts_with("set ")
        || start.starts_with("begin")
        || start.starts_with("commit")
        || start.starts_with("rollback")
        || start.starts_with("listen")
        || start.starts_with("notify")
        || start.starts_with("reset ")
    {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "This statement class is not allowed in BaaS SQL".into(),
        });
    }

    if is_read {
        if let Err(msg) = admin_sql::validate_admin_query(q, true, allow_raw, false) {
            return HttpResponse::Forbidden().json(ErrorResponse {
                error: msg.into(),
            });
        }
    } else if let Err(msg) = admin_sql::validate_admin_query(q, false, allow_raw, allow_write) {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: msg.into(),
        });
    }

    let set_path = format!(
        "SET LOCAL search_path = {}, pg_temp",
        quote_ident(&schema)
    );

    let mut tx = match state.pool.begin().await {
        Ok(t) => t,
        Err(e) => {
            log::error!("baas tx: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            });
        }
    };

    if sqlx::query(&set_path).execute(&mut *tx).await.is_err() {
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "failed to set search_path".into(),
        });
    }
    let _ = sqlx::query("SET LOCAL statement_timeout = '8000ms'")
        .execute(&mut *tx)
        .await;

    if is_read {
        match baas_query_with_params(&mut tx, q, &body.params).await {
            Ok(rows) => {
                if rows.len() > BAAS_MAX_SELECT_ROWS {
                    let _ = tx.rollback().await;
                    return HttpResponse::BadRequest().json(ErrorResponse {
                        error: format!("Too many rows (max {})", BAAS_MAX_SELECT_ROWS),
                    });
                }
                if let Err(e) = tx.commit().await {
                    log::error!("baas commit: {}", e);
                    return HttpResponse::InternalServerError().json(ErrorResponse {
                        error: "database error".into(),
                    });
                }
                if rows.is_empty() {
                    return HttpResponse::Ok().json(DbQueryResponse {
                        columns: vec![],
                        rows: vec![],
                    });
                }
                let columns: Vec<String> = rows[0]
                    .columns()
                    .iter()
                    .map(|c| c.name().to_string())
                    .collect();
                let json_rows: Vec<Value> = rows
                    .into_iter()
                    .map(|row| {
                        let mut map = serde_json::Map::new();
                        for col in &columns {
                            let value: Value =
                                row.try_get::<serde_json::Value, _>(col.as_str())
                                    .unwrap_or(Value::Null);
                            map.insert(col.clone(), value);
                        }
                        Value::Object(map)
                    })
                    .collect();
                HttpResponse::Ok().json(DbQueryResponse {
                    columns,
                    rows: json_rows,
                })
            }
            Err(e) => {
                let _ = tx.rollback().await;
                HttpResponse::BadRequest().json(ErrorResponse {
                    error: format!("Query error: {}", e),
                })
            }
        }
    } else {
        match baas_execute_with_params(&mut tx, q, &body.params).await {
            Ok(ra) => {
                if let Err(e) = tx.commit().await {
                    log::error!("baas commit: {}", e);
                    return HttpResponse::InternalServerError().json(ErrorResponse {
                        error: "database error".into(),
                    });
                }
                HttpResponse::Ok().json(json!({ "rows_affected": ra }))
            }
            Err(e) => {
                let _ = tx.rollback().await;
                HttpResponse::BadRequest().json(ErrorResponse {
                    error: format!("Query error: {}", e),
                })
            }
        }
    }
}

pub async fn list_tables(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let schema = match ensure_user_schema(&state.pool, uid).await {
        Ok(s) => s,
        Err(e) => {
            log::error!("baas: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "schema error".into(),
            });
        }
    };
    let rows: Result<Vec<(String,)>, _> = sqlx::query_as(
        r#"SELECT table_name FROM information_schema.tables
           WHERE table_schema = $1 AND table_type = 'BASE TABLE' ORDER BY table_name"#,
    )
    .bind(&schema)
    .fetch_all(&state.pool)
    .await;
    match rows {
        Ok(list) => HttpResponse::Ok().json(json!({
            "tables": list.into_iter().map(|(n,)| n).collect::<Vec<_>>(),
        })),
        Err(e) => {
            log::error!("baas list tables: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}

#[derive(Deserialize)]
pub struct CreateTableBody {
    name: String,
}

pub async fn create_table(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<CreateTableBody>,
) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    if !baas_allow_write(&state.config) {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "WM_BAAS_SQL_WRITE or ADMIN_ALLOW_SQL_WRITE required".into(),
        });
    }
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    if !valid_rel_identifier(&body.name) {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid table name".into(),
        });
    }
    let schema = match ensure_user_schema(&state.pool, uid).await {
        Ok(s) => s,
        Err(e) => {
            log::error!("baas: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "schema error".into(),
            });
        }
    };
    let fq = format!(
        "CREATE TABLE IF NOT EXISTS {}.{} ( id UUID PRIMARY KEY DEFAULT gen_random_uuid(), data JSONB NOT NULL DEFAULT '{}'::jsonb, created_at TIMESTAMPTZ NOT NULL DEFAULT now() )",
        quote_ident(&schema),
        quote_ident(&body.name),
        "{}"
    );
    match sqlx::query(&fq).execute(&state.pool).await {
        Ok(_) => HttpResponse::Ok().json(json!({ "ok": true, "table": body.name })),
        Err(e) => HttpResponse::BadRequest().json(ErrorResponse {
            error: format!("{}", e),
        }),
    }
}

#[derive(Debug, Deserialize)]
pub struct RestListQuery {
    #[serde(default = "default_rest_limit")]
    pub limit: i64,
    #[serde(default)]
    pub offset: i64,
    pub sort: Option<String>,
    pub order: Option<String>,
}

fn default_rest_limit() -> i64 {
    50
}

pub async fn rest_list(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<String>,
    q: web::Query<RestListQuery>,
) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    let table = path.into_inner();
    if !valid_rel_identifier(&table) {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid table name".into(),
        });
    }
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let schema = match ensure_user_schema(&state.pool, uid).await {
        Ok(s) => s,
        Err(e) => {
            log::error!("baas: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "schema error".into(),
            });
        }
    };
    let sort_col = match q.sort.as_deref() {
        Some("id") => "id",
        _ => "created_at",
    };
    let ord = match q.order.as_deref() {
        Some("asc") | Some("ASC") => "ASC",
        _ => "DESC",
    };
    let lim = q.limit.clamp(1, BAAS_MAX_SELECT_ROWS as i64);
    let off = q.offset.max(0);
    let sql = format!(
        "SELECT id, data, created_at FROM {}.{} ORDER BY {} {} LIMIT {} OFFSET {}",
        quote_ident(&schema),
        quote_ident(&table),
        sort_col,
        ord,
        lim,
        off
    );
    match sqlx::query(&sql).fetch_all(&state.pool).await {
        Ok(rows) => {
            let mut out = Vec::new();
            for row in rows {
                let id: Uuid = row.try_get("id").unwrap_or_default();
                let data: Value = row.try_get("data").unwrap_or(Value::Null);
                let created_at: chrono::DateTime<chrono::Utc> =
                    row.try_get("created_at").unwrap_or_else(|_| chrono::Utc::now());
                out.push(json!({
                    "id": id,
                    "data": data,
                    "created_at": created_at,
                }));
            }
            HttpResponse::Ok().json(json!({
                "rows": out,
                "limit": lim,
                "offset": off,
                "sort": sort_col,
                "order": ord,
            }))
        }
        Err(e) => HttpResponse::BadRequest().json(ErrorResponse {
            error: format!("{}", e),
        }),
    }
}

pub async fn rest_insert(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<String>,
    body: web::Json<Value>,
) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    let table = path.into_inner();
    if !valid_rel_identifier(&table) {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid table name".into(),
        });
    }
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let schema = match ensure_user_schema(&state.pool, uid).await {
        Ok(s) => s,
        Err(e) => {
            log::error!("baas: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "schema error".into(),
            });
        }
    };
    let sql = format!(
        "INSERT INTO {}.{} (data) VALUES ($1) RETURNING id, data, created_at",
        quote_ident(&schema),
        quote_ident(&table)
    );
    match sqlx::query(&sql)
        .bind(&*body)
        .fetch_one(&state.pool)
        .await
    {
        Ok(row) => {
            let id: Uuid = row.try_get("id").unwrap_or_default();
            let data: Value = row.try_get("data").unwrap_or(Value::Null);
            let created_at: chrono::DateTime<chrono::Utc> =
                row.try_get("created_at").unwrap_or_else(|_| chrono::Utc::now());
            let row_json = json!({ "id": id, "data": data.clone(), "created_at": created_at });
            emit_wm_baas_event(
                state.get_ref(),
                &state.pool,
                uid,
                &table,
                "insert",
                &row_json,
            )
            .await;
            HttpResponse::Ok().json(json!({ "id": id, "data": data, "created_at": created_at }))
        }
        Err(e) => HttpResponse::BadRequest().json(ErrorResponse {
            error: format!("{}", e),
        }),
    }
}

pub async fn rest_update(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<(String, Uuid)>,
    body: web::Json<Value>,
) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    if !baas_allow_write(&state.config) {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "WM_BAAS_SQL_WRITE or ADMIN_ALLOW_SQL_WRITE required".into(),
        });
    }
    let (table, id) = path.into_inner();
    if !valid_rel_identifier(&table) {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid table name".into(),
        });
    }
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let schema = match ensure_user_schema(&state.pool, uid).await {
        Ok(s) => s,
        Err(e) => {
            log::error!("baas: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "schema error".into(),
            });
        }
    };
    let sql = format!(
        "UPDATE {}.{} SET data = COALESCE(data, '{{}}'::jsonb) || $1::jsonb WHERE id = $2 RETURNING id, data, created_at",
        quote_ident(&schema),
        quote_ident(&table)
    );
    match sqlx::query(&sql)
        .bind(&*body)
        .bind(id)
        .fetch_optional(&state.pool)
        .await
    {
        Ok(Some(row)) => {
            let id: Uuid = row.try_get("id").unwrap_or_default();
            let data: Value = row.try_get("data").unwrap_or(Value::Null);
            let created_at: chrono::DateTime<chrono::Utc> =
                row.try_get("created_at").unwrap_or_else(|_| chrono::Utc::now());
            let row_json = json!({ "id": id, "data": data.clone(), "created_at": created_at });
            emit_wm_baas_event(state.get_ref(), &state.pool, uid, &table, "update", &row_json).await;
            HttpResponse::Ok().json(json!({ "id": id, "data": data, "created_at": created_at }))
        }
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "row not found".into(),
        }),
        Err(e) => HttpResponse::BadRequest().json(ErrorResponse {
            error: format!("{}", e),
        }),
    }
}

pub async fn rest_delete(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<(String, Uuid)>,
) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    let (table, id) = path.into_inner();
    if !valid_rel_identifier(&table) {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid table name".into(),
        });
    }
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let schema = match ensure_user_schema(&state.pool, uid).await {
        Ok(s) => s,
        Err(e) => {
            log::error!("baas: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "schema error".into(),
            });
        }
    };
    let sql = format!(
        "DELETE FROM {}.{} WHERE id = $1",
        quote_ident(&schema),
        quote_ident(&table)
    );
    match sqlx::query(&sql).bind(id).execute(&state.pool).await {
        Ok(r) => {
            let n = r.rows_affected();
            if n > 0 {
                emit_wm_baas_event(
                    state.get_ref(),
                    &state.pool,
                    uid,
                    &table,
                    "delete",
                    &json!({ "id": id }),
                )
                .await;
            }
            HttpResponse::Ok().json(json!({ "rows_affected": n }))
        }
        Err(e) => HttpResponse::BadRequest().json(ErrorResponse {
            error: format!("{}", e),
        }),
    }
}

#[derive(Serialize, sqlx::FromRow)]
struct BucketRow {
    id: Uuid,
    name: String,
    public_read: bool,
}

pub async fn buckets_list(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let _ = ensure_user_schema(&state.pool, uid).await;
    let rows: Result<Vec<BucketRow>, _> = sqlx::query_as(
        "SELECT id, name, public_read FROM wm_baas_buckets WHERE user_id = $1 ORDER BY name",
    )
    .bind(uid)
    .fetch_all(&state.pool)
    .await;
    match rows {
        Ok(b) => HttpResponse::Ok().json(json!({ "buckets": b })),
        Err(e) => {
            log::error!("baas buckets: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            })
        }
    }
}

pub async fn bootstrap(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let schema = match ensure_user_schema(&state.pool, uid).await {
        Ok(s) => s,
        Err(e) => {
            log::error!("baas bootstrap schema: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "schema error".into(),
            });
        }
    };
    let pool = state.pool.clone();
    let schema_for_tables = schema.clone();
    let tables_fut = async move {
        sqlx::query_as::<_, (String,)>(
            r#"SELECT table_name FROM information_schema.tables
           WHERE table_schema = $1 AND table_type = 'BASE TABLE' ORDER BY table_name"#,
        )
        .bind(&schema_for_tables)
        .fetch_all(&pool)
        .await
    };
    let pool2 = state.pool.clone();
    let buckets_fut = async move {
        sqlx::query_as::<_, BucketRow>(
            "SELECT id, name, public_read FROM wm_baas_buckets WHERE user_id = $1 ORDER BY name",
        )
        .bind(uid)
        .fetch_all(&pool2)
        .await
    };
    let (tables_res, buckets_res) = tokio::join!(tables_fut, buckets_fut);
    let tables = match tables_res {
        Ok(list) => list.into_iter().map(|(n,)| n).collect::<Vec<_>>(),
        Err(e) => {
            log::error!("baas bootstrap tables: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            });
        }
    };
    let buckets = match buckets_res {
        Ok(b) => b,
        Err(e) => {
            log::error!("baas bootstrap buckets: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            });
        }
    };
    HttpResponse::Ok().json(json!({
        "schema_name": schema,
        "tables": tables,
        "buckets": buckets,
    }))
}

#[derive(Deserialize)]
pub struct CreateBucketBody {
    name: String,
    #[serde(default)]
    public_read: bool,
}

pub async fn buckets_create(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<CreateBucketBody>,
) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    let name = body.name.trim();
    if name.is_empty() || name.len() > 128 || !name.chars().all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_') {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid bucket name".into(),
        });
    }
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let _ = ensure_user_schema(&state.pool, uid).await;
    let row: Result<(Uuid,), _> = sqlx::query_as(
        r#"INSERT INTO wm_baas_buckets (user_id, name, public_read) VALUES ($1, $2, $3)
           ON CONFLICT (user_id, name) DO UPDATE SET public_read = EXCLUDED.public_read
           RETURNING id"#,
    )
    .bind(uid)
    .bind(name)
    .bind(body.public_read)
    .fetch_one(&state.pool)
    .await;
    match row {
        Ok((id,)) => HttpResponse::Ok().json(json!({ "id": id, "name": name })),
        Err(e) => {
            log::error!("baas bucket create: {}", e);
            HttpResponse::BadRequest().json(ErrorResponse {
                error: "could not create bucket".into(),
            })
        }
    }
}

#[derive(Deserialize)]
pub struct ObjectKeyQuery {
    key: String,
}

fn sanitize_object_key(key: &str) -> Result<String, &'static str> {
    let k = key.trim();
    if k.is_empty() || k.len() > 512 {
        return Err("invalid key");
    }
    if k.contains("..") || k.starts_with('/') {
        return Err("invalid key");
    }
    Ok(k.to_string())
}

pub async fn object_put(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<String>,
    q: web::Query<ObjectKeyQuery>,
    mut payload: Multipart,
) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    let bucket_name = path.into_inner();
    let key = match sanitize_object_key(&q.key) {
        Ok(k) => k,
        Err(msg) => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: msg.into(),
            })
        }
    };
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let _ = ensure_user_schema(&state.pool, uid).await;

    let bucket_id = sqlx::query_as::<_, (Uuid,)>(
        "SELECT id FROM wm_baas_buckets WHERE user_id = $1 AND name = $2",
    )
    .bind(uid)
    .bind(&bucket_name)
    .fetch_optional(&state.pool)
    .await;
    let bid = match bucket_id {
        Ok(Some((id,))) => id,
        Ok(None) => {
            return HttpResponse::NotFound().json(ErrorResponse {
                error: "bucket not found".into(),
            })
        }
        Err(e) => {
            log::error!("baas bucket lookup: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            });
        }
    };

    let max_b = max_object_bytes();
    let mut file_bytes: Vec<u8> = Vec::new();
    let mut content_type: Option<String> = None;

    while let Some(Ok(mut field)) = payload.next().await {
        let cd = field.content_disposition().cloned();
        let fname = cd.as_ref().and_then(|c| c.get_name()).unwrap_or("");
        if fname == "file" {
            if let Some(ct) = field.content_type() {
                content_type = Some(ct.to_string());
            }
            while let Some(Ok(chunk)) = field.next().await {
                if file_bytes.len().saturating_add(chunk.len()) > max_b {
                    return HttpResponse::BadRequest().json(ErrorResponse {
                        error: "Object too large".into(),
                    });
                }
                file_bytes.extend_from_slice(&chunk);
            }
        }
    }

    if file_bytes.is_empty() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "multipart field 'file' required".into(),
        });
    }

    let root = storage_root();
    let safe_key = key.replace(['/', '\\'], "_");
    let rel = format!("{}/{}/{}", uid, bid, safe_key);
    let disk_path = root.join(&rel);
    if let Some(parent) = disk_path.parent() {
        if let Err(e) = fs::create_dir_all(parent).await {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: format!("mkdir: {}", e),
            });
        }
    }
    let mut f = match fs::File::create(&disk_path).await {
        Ok(f) => f,
        Err(e) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: format!("create file: {}", e),
            })
        }
    };
    if let Err(e) = f.write_all(&file_bytes).await {
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: format!("write: {}", e),
        });
    }

    let size = file_bytes.len() as i64;
    let storage_path = rel;
    let ct = content_type.unwrap_or_else(|| "application/octet-stream".into());

    let res = sqlx::query(
        r#"INSERT INTO wm_baas_objects (bucket_id, object_key, content_type, size_bytes, storage_path)
           VALUES ($1, $2, $3, $4, $5)
           ON CONFLICT (bucket_id, object_key)
           DO UPDATE SET content_type = EXCLUDED.content_type, size_bytes = EXCLUDED.size_bytes, storage_path = EXCLUDED.storage_path
           RETURNING id"#,
    )
    .bind(bid)
    .bind(&key)
    .bind(&ct)
    .bind(size)
    .bind(&storage_path)
    .fetch_one(&state.pool)
    .await;

    match res {
        Ok(row) => {
            let oid: Uuid = match row.try_get("id") {
                Ok(v) => v,
                Err(e) => {
                    log::error!("baas object id: {}", e);
                    return HttpResponse::InternalServerError().json(ErrorResponse {
                        error: "metadata parse failed".into(),
                    });
                }
            };
            HttpResponse::Ok().json(json!({
                "id": oid,
                "key": key,
                "size_bytes": size,
                "content_type": ct,
            }))
        }
        Err(e) => {
            log::error!("baas object meta: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "metadata save failed".into(),
            })
        }
    }
}

pub async fn object_get(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<String>,
    q: web::Query<ObjectKeyQuery>,
) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    let bucket_name = path.into_inner();
    let key = match sanitize_object_key(&q.key) {
        Ok(k) => k,
        Err(msg) => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: msg.into(),
            })
        }
    };
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };

    let row = sqlx::query_as::<_, (String, String, i64)>(
        r#"SELECT o.storage_path, o.content_type, o.size_bytes
           FROM wm_baas_objects o
           JOIN wm_baas_buckets b ON b.id = o.bucket_id
           WHERE b.user_id = $1 AND b.name = $2 AND o.object_key = $3"#,
    )
    .bind(uid)
    .bind(&bucket_name)
    .bind(&key)
    .fetch_optional(&state.pool)
    .await;

    let (storage_path, content_type, _) = match row {
        Ok(Some(r)) => r,
        Ok(None) => {
            return HttpResponse::NotFound().json(ErrorResponse {
                error: "object not found".into(),
            })
        }
        Err(e) => {
            log::error!("baas object meta: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            });
        }
    };

    serve_object_file(&storage_path, &content_type, false).await
}

async fn serve_object_file(storage_path: &str, content_type: &str, public_cache: bool) -> HttpResponse {
    let full = storage_root().join(storage_path);
    let cache = if public_cache {
        "public, max-age=3600"
    } else {
        "private, no-store"
    };
    match fs::read(&full).await {
        Ok(bytes) => HttpResponse::Ok()
            .content_type(content_type)
            .insert_header(("Cache-Control", cache))
            .body(bytes),
        Err(e) => {
            log::error!("baas read object: {}", e);
            HttpResponse::NotFound().json(ErrorResponse {
                error: "file missing".into(),
            })
        }
    }
}

pub async fn object_get_public(
    state: web::Data<AppState>,
    path: web::Path<(Uuid, String)>,
    q: web::Query<ObjectKeyQuery>,
) -> impl Responder {
    if baas_globally_disabled() {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "BaaS module disabled".into(),
        });
    }
    let (owner_id, bucket_name) = path.into_inner();
    let key = match sanitize_object_key(&q.key) {
        Ok(k) => k,
        Err(msg) => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: msg.into(),
            })
        }
    };

    let row = sqlx::query_as::<_, (String, String)>(
        r#"SELECT o.storage_path, o.content_type
           FROM wm_baas_objects o
           JOIN wm_baas_buckets b ON b.id = o.bucket_id
           WHERE b.user_id = $1 AND b.name = $2 AND b.public_read = true AND o.object_key = $3"#,
    )
    .bind(owner_id)
    .bind(&bucket_name)
    .bind(&key)
    .fetch_optional(&state.pool)
    .await;

    let (storage_path, content_type) = match row {
        Ok(Some(r)) => r,
        Ok(None) => {
            return HttpResponse::NotFound().json(ErrorResponse {
                error: "not found or not public".into(),
            })
        }
        Err(e) => {
            log::error!("baas public object: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "database error".into(),
            });
        }
    };

    serve_object_file(&storage_path, &content_type, true).await
}
