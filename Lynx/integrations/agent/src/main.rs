
mod sql_guard;

use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::{postgres::PgPoolOptions, Column, Row};
use sql_guard::validate_agent_readonly;
use std::sync::Arc;
use std::time::Duration;
use tracing::{error, info, warn};

#[derive(Clone)]
struct AppState {
    pool: sqlx::PgPool,
    expected_key: String,
    heartbeat_url: Option<String>,
    heartbeat_interval_secs: u64,
}

#[derive(Deserialize)]
struct SqlBody {
    query: String,
}

#[derive(Serialize)]
struct SqlResponse {
    columns: Vec<String>,
    rows: Vec<Value>,
}

fn bad_request(msg: &str) -> (StatusCode, Json<Value>) {
    (
        StatusCode::BAD_REQUEST,
        Json(json!({ "error": msg })),
    )
}

fn forbidden(msg: &str) -> (StatusCode, Json<Value>) {
    (
        StatusCode::FORBIDDEN,
        Json(json!({ "error": msg })),
    )
}

async fn sql_handler(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(body): Json<SqlBody>,
) -> Result<Json<SqlResponse>, (StatusCode, Json<Value>)> {
    let key = headers
        .get("X-Agent-Key")
        .and_then(|h| h.to_str().ok())
        .map(str::trim)
        .filter(|s| !s.is_empty());
    if key != Some(state.expected_key.as_str()) {
        return Err(forbidden("Invalid X-Agent-Key"));
    }

    let query = body.query.trim();
    if let Err(e) = validate_agent_readonly(query) {
        return Err(bad_request(e));
    }

    let result = sqlx::query(query).fetch_all(&state.pool).await.map_err(|e| {
        error!("sql: {}", e);
        bad_request(&format!("Query error: {}", e))
    })?;

    if result.is_empty() {
        return Ok(Json(SqlResponse {
            columns: vec![],
            rows: vec![],
        }));
    }

    let columns: Vec<String> = result[0]
        .columns()
        .iter()
        .map(|c| c.name().to_string())
        .collect();
    let json_rows: Vec<Value> = result
        .into_iter()
        .map(|row| {
            let mut map = serde_json::Map::new();
            for col in &columns {
                let value: Value = row.try_get(col.as_str()).unwrap_or(Value::Null);
                map.insert(col.clone(), value);
            }
            Value::Object(map)
        })
        .collect();

    Ok(Json(SqlResponse {
        columns,
        rows: json_rows,
    }))
}

const SCHEMA_QUERY: &str = r#"
SELECT
  c.table_schema,
  c.table_name,
  c.column_name,
  c.data_type,
  c.is_nullable
FROM information_schema.columns c
WHERE c.table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY c.table_schema, c.table_name, c.ordinal_position
LIMIT 5000
"#;

const FK_QUERY: &str = r#"
SELECT
  kcu.table_schema,
  kcu.table_name,
  kcu.column_name,
  ccu.table_schema AS ref_schema,
  ccu.table_name AS ref_table,
  ccu.column_name AS ref_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_schema = kcu.constraint_schema
  AND tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_schema = tc.constraint_schema
  AND ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema NOT IN ('pg_catalog', 'information_schema')
LIMIT 2000
"#;

async fn schema_snapshot(pool: &sqlx::PgPool) -> Result<Value, sqlx::Error> {
    let rows = sqlx::query(SCHEMA_QUERY).fetch_all(pool).await?;
    let mut tables: serde_json::Map<String, Value> = serde_json::Map::new();
    for row in rows {
        let schema: String = row.try_get("table_schema").unwrap_or_default();
        let table: String = row.try_get("table_name").unwrap_or_default();
        let col: String = row.try_get("column_name").unwrap_or_default();
        let dtype: String = row.try_get("data_type").unwrap_or_default();
        let nullable: String = row.try_get("is_nullable").unwrap_or_default();
        let fq = format!("{}.{}", schema, table);
        let entry = tables.entry(fq.clone()).or_insert_with(|| {
            json!({
                "schema": schema,
                "name": table,
                "columns": [],
                "foreign_keys": []
            })
        });
        if let Some(arr) = entry.get_mut("columns").and_then(|c| c.as_array_mut()) {
            arr.push(json!({
                "name": col,
                "data_type": dtype,
                "nullable": nullable == "YES"
            }));
        }
    }

    let fk_rows = sqlx::query(FK_QUERY).fetch_all(pool).await?;
    for row in fk_rows {
        let schema: String = row.try_get("table_schema").unwrap_or_default();
        let table: String = row.try_get("table_name").unwrap_or_default();
        let col: String = row.try_get("column_name").unwrap_or_default();
        let ref_schema: String = row.try_get("ref_schema").unwrap_or_default();
        let ref_table: String = row.try_get("ref_table").unwrap_or_default();
        let ref_col: String = row.try_get("ref_column").unwrap_or_default();
        let fq = format!("{}.{}", schema, table);
        if let Some(entry) = tables.get_mut(&fq) {
            let fk = json!({
                "column": col,
                "ref_table": format!("{}.{}", ref_schema, ref_table),
                "ref_column": ref_col
            });
            if let Some(o) = entry.as_object_mut() {
                let fk_arr = o
                    .entry("foreign_keys")
                    .or_insert_with(|| json!([]))
                    .as_array_mut();
                if let Some(a) = fk_arr {
                    a.push(fk);
                }
            }
        }
    }

    Ok(Value::Object(tables))
}

async fn schema_handler(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let key = headers
        .get("X-Agent-Key")
        .and_then(|h| h.to_str().ok())
        .map(str::trim)
        .filter(|s| !s.is_empty());
    if key != Some(state.expected_key.as_str()) {
        return Err(forbidden("Invalid X-Agent-Key"));
    }

    schema_snapshot(&state.pool)
        .await
        .map(Json)
        .map_err(|e| {
            error!("schema: {}", e);
            bad_request(&format!("Schema query error: {}", e))
        })
}

async fn health() -> &'static str {
    "ok"
}

async fn push_heartbeat(state: Arc<AppState>, schema: Value) {
    let Some(ref url) = state.heartbeat_url else {
        return;
    };
    let client = match reqwest::Client::builder()
        .timeout(Duration::from_secs(30))
        .build()
    {
        Ok(c) => c,
        Err(e) => {
            warn!("heartbeat client: {}", e);
            return;
        }
    };
    let res = client
        .post(url)
        .header("X-Agent-Key", &state.expected_key)
        .json(&json!({ "schema": schema }))
        .send()
        .await;
    match res {
        Ok(r) if r.status().is_success() => info!("heartbeat ok"),
        Ok(r) => warn!("heartbeat HTTP {}", r.status()),
        Err(e) => warn!("heartbeat: {}", e),
    }
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .init();

    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set (PostgreSQL connection string)");
    let expected_key =
        std::env::var("NEXUS_AGENT_KEY").expect("NEXUS_AGENT_KEY must match workspace agent_api_key");
    let heartbeat_url = std::env::var("NEXUS_HEARTBEAT_URL").ok().filter(|s| !s.is_empty());
    let heartbeat_interval_secs: u64 = std::env::var("NEXUS_HEARTBEAT_INTERVAL_SECS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(120);

    let bind = std::env::var("NEXUS_AGENT_BIND").unwrap_or_else(|_| "0.0.0.0:9847".into());

    let pool = PgPoolOptions::new()
        .max_connections(8)
        .connect(&database_url)
        .await?;

    let state = Arc::new(AppState {
        pool: pool.clone(),
        expected_key,
        heartbeat_url,
        heartbeat_interval_secs,
    });

    if state.heartbeat_url.is_some() {
        let st = state.clone();
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(st.heartbeat_interval_secs));
            loop {
                interval.tick().await;
                let schema = match schema_snapshot(&st.pool).await {
                    Ok(v) => v,
                    Err(e) => {
                        error!("heartbeat schema load: {}", e);
                        continue;
                    }
                };
                push_heartbeat(st.clone(), schema).await;
            }
        });
    }

    let app = Router::new()
        .route("/v1/sql", post(sql_handler))
        .route("/v1/schema", get(schema_handler))
        .route("/health", get(health))
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(&bind).await?;
    info!("nexus-agent listening on http://{}", bind);
    axum::serve(listener, app).await?;
    Ok(())
}
