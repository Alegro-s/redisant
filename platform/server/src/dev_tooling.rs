use actix_web::{web, HttpRequest, HttpResponse, Responder};
use chrono::{DateTime, Utc};
use serde::Serialize;
use serde_json::json;
use uuid::Uuid;

use crate::{get_user_id_from_token, AppState, ErrorResponse};

fn jwt_secret() -> Result<String, HttpResponse> {
    std::env::var("JWT_SECRET").map_err(|_| {
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

#[derive(Serialize, sqlx::FromRow)]
struct ExportRow {
    name: String,
    value: f64,
    tags: Option<serde_json::Value>,
    timestamp: DateTime<Utc>,
}

#[derive(serde::Deserialize)]
pub struct ExportQuery {
    pub limit: Option<i64>,
}

pub async fn ingest_export(
    state: web::Data<AppState>,
    req: HttpRequest,
    q: web::Query<ExportQuery>,
) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let lim = q.limit.unwrap_or(500).clamp(1, 5000);

    let rows = sqlx::query_as::<_, ExportRow>(
        r#"SELECT m.name, m.value, m.tags, m.timestamp
           FROM ingested_metrics m
           JOIN api_keys k ON m.api_key_id = k.id
           WHERE k.user_id = $1
           ORDER BY m.timestamp DESC
           LIMIT $2"#,
    )
    .bind(uid)
    .bind(lim)
    .fetch_all(&state.pool)
    .await;

    match rows {
        Ok(r) => HttpResponse::Ok().json(json!({
            "exported_at": Utc::now(),
            "limit": lim,
            "count": r.len(),
            "metrics": r,
        })),
        Err(e) => {
            log::error!("ingest_export: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "export failed".into(),
            })
        }
    }
}

#[derive(serde::Deserialize)]
pub struct ReplayBody {
    #[serde(default = "default_replay_limit")]
    pub limit: i64,
}

fn default_replay_limit() -> i64 {
    200
}

pub async fn ingest_replay(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<ReplayBody>,
) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };
    let lim = body.limit.clamp(1, 2000);

    let res = sqlx::query(
        r#"
        INSERT INTO ingested_metrics (api_key_id, name, value, tags, timestamp)
        SELECT sub.api_key_id, sub.name, sub.value,
               COALESCE(sub.tags, '{}'::jsonb) || jsonb_build_object(
                 'replay', true,
                 'replay_source_ts', to_jsonb(sub.ts::text)
               ),
               NOW()
        FROM (
          SELECT m.api_key_id, m.name, m.value, COALESCE(m.tags, '{}'::jsonb) AS tags, m.timestamp AS ts
          FROM ingested_metrics m
          JOIN api_keys k ON m.api_key_id = k.id
          WHERE k.user_id = $1
          ORDER BY m.timestamp DESC
          LIMIT $2
        ) sub
        "#,
    )
    .bind(uid)
    .bind(lim)
    .execute(&state.pool)
    .await;

    match res {
        Ok(r) => HttpResponse::Ok().json(json!({
            "ok": true,
            "inserted": r.rows_affected(),
            "limit": lim,
        })),
        Err(e) => {
            log::error!("ingest_replay: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "replay failed".into(),
            })
        }
    }
}

pub async fn repro_bundle(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let uid = match auth_uid(&req) {
        Ok(u) => u,
        Err(e) => return e,
    };

    let ws: Option<(Option<String>, Option<String>, Option<String>, bool, bool)> =
        sqlx::query_as(
            r#"SELECT db_mode, agent_api_key, connection_url, server_hosting, onboarding_completed
               FROM user_workspace WHERE user_id = $1"#,
        )
        .bind(uid)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None);

    let (db_mode, agent_key, conn_url, hosting, onb) = ws.unwrap_or((None, None, None, false, false));

    fn mask(s: &Option<String>) -> Option<String> {
        s.as_ref().map(|k| {
            let t = k.trim();
            if t.len() <= 6 {
                "***".into()
            } else {
                format!("…{}", &t[t.len() - 4..])
            }
        })
    }

    let total: (i64,) = sqlx::query_as(
        r#"SELECT COUNT(*)::bigint FROM ingested_metrics m
           JOIN api_keys k ON m.api_key_id = k.id WHERE k.user_id = $1"#,
    )
    .bind(uid)
    .fetch_one(&state.pool)
    .await
    .unwrap_or((0,));

    let names: Vec<(String, i64)> = sqlx::query_as(
        r#"SELECT m.name, COUNT(*)::bigint FROM ingested_metrics m
           JOIN api_keys k ON m.api_key_id = k.id
           WHERE k.user_id = $1
           GROUP BY m.name ORDER BY COUNT(*) DESC LIMIT 30"#,
    )
    .bind(uid)
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    HttpResponse::Ok().json(json!({
        "generated_at": Utc::now(),
        "hint": "Прикрепите к обращению в поддержку (без раскрытия полных ключей).",
        "workspace": {
            "onboarding_completed": onb,
            "db_mode": db_mode,
            "server_hosting": hosting,
            "connection_url": conn_url,
            "agent_api_key_tail": mask(&agent_key),
        },
        "ingest": {
            "metrics_total": total.0,
            "top_metric_names": names.into_iter().map(|(n, c)| json!({"name": n, "count": c})).collect::<Vec<_>>(),
        },
    }))
}
