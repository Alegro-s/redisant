use actix_web::{web, App, HttpServer, HttpResponse, Responder, HttpRequest};
use actix_governor::{Governor, GovernorConfigBuilder};
use actix_web::middleware::Condition;
use actix_multipart::Multipart;
use futures_util::stream::StreamExt as _;
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, postgres::PgPoolOptions, Row, Column};
use jsonwebtoken::{encode, decode, Header, EncodingKey, DecodingKey, Validation, Algorithm};
use chrono::{Utc, Duration, DateTime};
use uuid::Uuid;
use dotenvy::dotenv;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use log::{info, error};
use sha2::{Sha256, Digest};
use sysinfo::{System, Disks, Networks};
use tokio::sync::Mutex;
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use tokio::time;
use std::collections::HashMap;
use actix_web::body::MessageBody;
use actix_web::dev::{ServiceRequest, ServiceResponse};
use actix_web::middleware::{from_fn, Next};

mod waypoint;
mod access;
mod admin_sql;
mod alert;
mod config;
mod session;
mod authz;
mod logging;
mod social;
mod auth_challenge;
mod blocking;
mod desktop_devices;

#[derive(Clone, Serialize)]
struct MetricPoint {
    time: String,
    cpu: f64,
    memory: f64,
    total_memory: f64,
    disk_io: f64,
    network_rx: f64,
    network_tx: f64,
    requests: usize,
}

struct MetricsStore {
    points: Vec<MetricPoint>,
    max_size: usize,
    last_disk_read: u64,
    last_disk_write: u64,
    last_net_rx: u64,
    last_net_tx: u64,
    last_time: DateTime<Utc>,
}

impl MetricsStore {
    fn new(max_size: usize) -> Self {
        MetricsStore {
            points: Vec::with_capacity(max_size),
            max_size,
            last_disk_read: 0,
            last_disk_write: 0,
            last_net_rx: 0,
            last_net_tx: 0,
            last_time: Utc::now(),
        }
    }

    fn add_point(
        &mut self,
        sys: &System,
        disks: &Disks,
        networks: &Networks,
        http_requests_since_last_tick: usize,
    ) {
        let now = Utc::now();

        let cpu_usage = sys.global_cpu_usage() as f64;

        let total_memory = sys.total_memory() as f64 / 1024.0 / 1024.0;
        let used_memory = sys.used_memory() as f64 / 1024.0 / 1024.0;

        let total_read = disks.iter().map(|d| d.usage().read_bytes).sum::<u64>();
        let total_write = disks.iter().map(|d| d.usage().written_bytes).sum::<u64>();
        let delta = (now - self.last_time).num_milliseconds() as f64 / 1000.0;

        let disk_read_diff = total_read.saturating_sub(self.last_disk_read);
        let disk_write_diff = total_write.saturating_sub(self.last_disk_write);

        let disk_read_speed = if delta > 0.0 {
            disk_read_diff as f64 / delta / 1024.0 / 1024.0
        } else {
            0.0
        };
        let disk_write_speed = if delta > 0.0 {
            disk_write_diff as f64 / delta / 1024.0 / 1024.0
        } else {
            0.0
        };

        let total_rx = networks.iter().map(|(_, data)| data.received()).sum::<u64>();
        let total_tx = networks.iter().map(|(_, data)| data.transmitted()).sum::<u64>();

        let net_rx_diff = total_rx.saturating_sub(self.last_net_rx);
        let net_tx_diff = total_tx.saturating_sub(self.last_net_tx);

        let net_rx_speed = if delta > 0.0 {
            net_rx_diff as f64 / delta / 1024.0
        } else {
            0.0
        };
        let net_tx_speed = if delta > 0.0 {
            net_tx_diff as f64 / delta / 1024.0
        } else {
            0.0
        };

        let rps = if delta > 0.0 {
            (http_requests_since_last_tick as f64 / delta) as usize
        } else {
            0
        };

        let point = MetricPoint {
            time: now.to_rfc3339_opts(chrono::SecondsFormat::Secs, true),
            cpu: cpu_usage,
            memory: used_memory,
            total_memory,
            disk_io: (disk_read_speed + disk_write_speed) / 2.0,
            network_rx: net_rx_speed,
            network_tx: net_tx_speed,
            requests: rps,
        };

        self.last_disk_read = total_read;
        self.last_disk_write = total_write;
        self.last_net_rx = total_rx;
        self.last_net_tx = total_tx;
        self.last_time = now;

        if self.points.len() >= self.max_size {
            self.points.remove(0);
        }
        self.points.push(point);
    }

    fn get_points(&self) -> Vec<MetricPoint> {
        self.points.clone()
    }
}

#[derive(Default)]
struct ConnectedMetricsStore {
    per_agent: HashMap<String, Vec<MetricPoint>>,
    max_size: usize,
}

impl ConnectedMetricsStore {
    fn new(max_size: usize) -> Self {
        Self {
            per_agent: HashMap::new(),
            max_size,
        }
    }

    fn add_point_for_agent(&mut self, agent_key: &str, point: MetricPoint) {
        let entry = self.per_agent.entry(agent_key.to_string()).or_default();
        if entry.len() >= self.max_size {
            entry.remove(0);
        }
        entry.push(point);
    }

    fn get_points_for_agent(&self, agent_key: &str) -> Vec<MetricPoint> {
        self.per_agent.get(agent_key).cloned().unwrap_or_default()
    }
}

pub(crate) struct AppState {
    pub pool: PgPool,
    pub(crate) metrics: Arc<Mutex<MetricsStore>>,
    pub(crate) connected_metrics: Arc<Mutex<ConnectedMetricsStore>>,
    pub(crate) http_request_counter: Arc<AtomicUsize>,
    pub config: Arc<config::RuntimeConfig>,
    pub scene_collab: Arc<scene_ws::SceneCollab>,
    pub studio_collab: Arc<studio_ws::StudioCollab>,
    pub prometheus: Option<std::sync::Arc<observability::PrometheusHandles>>,
    pub http_client: reqwest::Client,
    pub redis: Option<redis::aio::ConnectionManager>,
}

mod routes_extra;
mod vk_notify;
mod engine_releases;
mod artifact_channels;
mod dev_tooling;
mod project_scenes;
mod key_pool;
mod bootstrap;
mod platform;
mod python_tests;
mod baas;
mod rate_limit_key;
mod nexus_cloud;
mod nexus_cloud_builds;
mod waypoint_ai;
mod waypoint_cabinet;
mod waypoint_metric;
mod observability;
mod clickhouse_sink;
mod wm_baas_realtime;
mod openapi_doc;
mod agent_integration;
mod engine_download;
mod scene_collab_crdt;
mod scene_ws;
mod studio_ws;
mod billing;
mod roza_cabinet;
mod email_verification;
mod password_policy;
mod service;
mod vk_oauth;
mod yandex_oauth;

#[macro_use]
mod routes_macro;

macro_rules! debug_print {
    ($($arg:tt)*) => {
        println!("[DEBUG] {}", format!($($arg)*));
    };
}

#[derive(Deserialize)]
struct RegisterRequest {
    email: String,
    phone: Option<String>,
    full_name: String,
    nickname: String,
    password: String,
    #[serde(default)]
    settings: serde_json::Value,
}

#[derive(Deserialize)]
struct LoginRequest {
    login: String,
    password: String,
}

#[derive(Serialize)]
pub(crate) struct AuthResponse {
    token: String,
    user_id: String,
    nickname: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    ingest_api_key: Option<String>,
}

pub(crate) async fn auth_json_for_user(
    pool: &PgPool,
    user_id: Uuid,
    nickname: &str,
    jwt_secret: &str,
    ttl_hours: i64,
) -> Result<AuthResponse, String> {
    let token = create_token(&user_id.to_string(), jwt_secret, ttl_hours).map_err(|e| e.to_string())?;
    let ingest_api_key: Option<String> =
        sqlx::query_scalar("SELECT key FROM api_keys WHERE user_id = $1 AND name = 'default' LIMIT 1")
            .bind(user_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| e.to_string())?
            .flatten();
    Ok(AuthResponse {
        token,
        user_id: user_id.to_string(),
        nickname: nickname.to_string(),
        ingest_api_key,
    })
}

#[derive(Serialize)]
pub(crate) struct ErrorResponse {
    error: String,
}

#[derive(Deserialize)]
struct UpdateProfileRequest {
    full_name: Option<String>,
    avatar_url: Option<String>,
    settings: Option<serde_json::Value>,
}

#[derive(Serialize)]
struct UserProfileResponse {
    id: String,
    email: String,
    phone: Option<String>,
    full_name: String,
    nickname: String,
    avatar_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    role: Option<String>,
    created_at: chrono::DateTime<chrono::Utc>,
    settings: serde_json::Value,
    realms: Vec<String>,
    email_verified: bool,
}

#[derive(Deserialize)]
struct LinkRealmRequest {
    password: String,
    realm: String,
}

#[derive(Deserialize)]
struct CreateProjectRequest {
    name: String,
    description: Option<String>,
    visibility: Option<String>,
}

#[derive(Serialize)]
struct ProjectResponse {
    id: String,
    owner_id: String,
    name: String,
    description: Option<String>,
    visibility: String,
    root_folder: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    share_slug: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    my_role: Option<String>,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Serialize)]
struct AssetResponse {
    id: String,
    project_id: String,
    name: String,
    r#type: String,
    size: Option<i64>,
    hash: Option<String>,
    storage_path: Option<String>,
    metadata: serde_json::Value,
    created_by: Option<String>,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Deserialize)]
struct AdminLoginRequest {
    login: String,
    password: String,
}

#[derive(Deserialize)]
struct AdminKeyCreateRequest {
    note: Option<String>,
    expires_in_days: Option<i64>,
    #[serde(default)]
    key_kind: Option<String>,
}

#[derive(Deserialize)]
struct AdminActivateRequest {
    key: String,
}

#[derive(Serialize)]
struct AdminAuthResponse {
    token: String,
    user_id: String,
    role: String,
}

#[derive(Serialize)]
struct AdminKeyCreateResponse {
    id: String,
    key: String,
    key_prefix: String,
    expires_at: Option<chrono::DateTime<chrono::Utc>>,
    created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Serialize)]
struct AdminKeyItemResponse {
    id: String,
    key_prefix: String,
    note: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    created_by: Option<String>,
    created_at: chrono::DateTime<chrono::Utc>,
    expires_at: Option<chrono::DateTime<chrono::Utc>>,
    used_at: Option<chrono::DateTime<chrono::Utc>>,
    revoked_at: Option<chrono::DateTime<chrono::Utc>>,
    used_by_email: Option<String>,
    #[serde(default)]
    key_kind: String,
    #[serde(default)]
    pool_generated: bool,
}

#[derive(Serialize)]
struct AdminUserResponse {
    id: String,
    email: String,
    phone: Option<String>,
    full_name: String,
    nickname: String,
    avatar_url: Option<String>,
    role: String,
    blocked: bool,
    coins: i64,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Serialize)]
struct AdminProjectResponse {
    id: String,
    owner_id: String,
    owner_name: Option<String>,
    name: String,
    description: Option<String>,
    visibility: String,
    root_folder: Option<String>,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
    asset_count: Option<i64>,
}

#[derive(Serialize)]
struct AdminAssetResponse {
    id: String,
    project_id: String,
    project_name: Option<String>,
    name: String,
    r#type: String,
    size: Option<i64>,
    hash: Option<String>,
    storage_path: Option<String>,
    created_by: Option<String>,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Serialize)]
struct StatsResponse {
    users: i64,
    projects: i64,
    assets: i64,
    active_sessions: i64,
}

#[derive(Deserialize)]
struct BlockUserRequest {
    blocked: bool,
}

#[derive(Deserialize)]
struct UpdateUserRequest {
    full_name: Option<String>,
    role: Option<String>,
    coins: Option<i64>,
}

#[derive(Deserialize)]
struct DbQueryRequest {
    query: String,
    read_only: bool,
}

#[derive(Serialize)]
pub(crate) struct DbQueryResponse {
    columns: Vec<String>,
    rows: Vec<serde_json::Value>,
}

#[derive(Deserialize)]
struct LogsQuery {
    limit: Option<usize>,
}

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: String,
    exp: usize,
}

pub(crate) fn create_token(
    user_id: &str,
    secret: &str,
    ttl_hours: i64,
) -> Result<String, jsonwebtoken::errors::Error> {
    let hours = ttl_hours.clamp(1, 168);
    let expiration = Utc::now()
        .checked_add_signed(Duration::hours(hours))
        .expect("valid timestamp")
        .timestamp() as usize;
    let claims = Claims { sub: user_id.to_string(), exp: expiration };
    encode(&Header::default(), &claims, &EncodingKey::from_secret(secret.as_ref()))
}

pub(crate) fn get_user_id_from_token(req: &HttpRequest, secret: &str) -> Option<Uuid> {
    if let Some(auth_header) = req.headers().get(actix_web::http::header::AUTHORIZATION) {
        if let Ok(s) = auth_header.to_str() {
            if let Some(rest) = s.strip_prefix("Bearer ") {
                if let Some(uid) = get_user_id_from_jwt_str(rest, secret) {
                    return Some(uid);
                }
            }
        }
    }
    if let Some(c) = req.cookie(session::SESSION_COOKIE) {
        if let Some(uid) = get_user_id_from_jwt_str(c.value(), secret) {
            return Some(uid);
        }
    }
    if let Some(c) = req.cookie(session::SESSION_COOKIE_LEGACY) {
        return get_user_id_from_jwt_str(c.value(), secret);
    }
    None
}

pub(crate) fn get_user_id_from_jwt_str(token: &str, secret: &str) -> Option<Uuid> {
    let decoding_key = DecodingKey::from_secret(secret.as_ref());
    let validation = Validation::new(Algorithm::HS256);
    let token_data = decode::<Claims>(token.trim(), &decoding_key, &validation).ok()?;
    Uuid::parse_str(&token_data.claims.sub).ok()
}

pub(crate) async fn is_admin(pool: &PgPool, user_id: Uuid) -> bool {
    let result: Result<Option<(String,)>, _> = sqlx::query_as("SELECT role FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_optional(pool)
        .await;
    match result {
        Ok(Some((role,))) => role == "admin" || role == "nexus",
        _ => false,
    }
}

pub(crate) async fn is_nexus(pool: &PgPool, user_id: Uuid) -> bool {
    let result: Result<Option<(String,)>, _> = sqlx::query_as("SELECT role FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_optional(pool)
        .await;
    matches!(result, Ok(Some((r,))) if r == "nexus")
}

pub(crate) fn generate_admin_activation_key() -> String {
    let mut out = format!(
        "{}{}",
        Uuid::new_v4().as_simple(),
        Uuid::new_v4().as_simple()
    );
    out.truncate(60);
    out
}

pub(crate) fn hash_admin_activation_key(raw_key: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(raw_key.as_bytes());
    format!("{:x}", hasher.finalize())
}

pub(crate) fn client_realm_from_header(req: &HttpRequest) -> Option<&'static str> {
    let h = req.headers().get("X-Client-Realm")?.to_str().ok()?.trim().to_lowercase();
    match h.as_str() {
        "nexus" | "lynx" => Some("nexus"),
        "metric" => Some("metric"),
        "roza" => Some("roza"),
        _ => None,
    }
}

pub(crate) async fn user_has_realm(pool: &PgPool, user_id: Uuid, realm: &str) -> bool {
    sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM user_realm WHERE user_id = $1 AND realm = $2)",
    )
    .bind(user_id)
    .bind(realm)
    .fetch_one(pool)
    .await
    .unwrap_or(false)
}

async fn grant_realms_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    user_id: Uuid,
    realms: &[&str],
) -> Result<(), sqlx::Error> {
    for r in realms {
        sqlx::query("INSERT INTO user_realm (user_id, realm) VALUES ($1, $2) ON CONFLICT DO NOTHING")
            .bind(user_id)
            .bind(*r)
            .execute(&mut **tx)
            .await?;
    }
    Ok(())
}

fn ensure_project_root(project_id: &Uuid) -> std::io::Result<String> {
    let root = format!("./uploads/{}", project_id);
    fs::create_dir_all(&root)?;
    Ok(root)
}

fn realms_for_registration(req: &HttpRequest) -> Result<Vec<&'static str>, HttpResponse> {
    let Some(realm) = client_realm_from_header(req) else {
        return Err(HttpResponse::BadRequest().json(ErrorResponse {
            error: "Заголовок X-Client-Realm обязателен (metric, lynx, roza).".into(),
        }));
    };
    Ok(match realm {
        "metric" => vec!["metric"],
        "nexus" => vec!["nexus"],
        "roza" => vec!["roza"],
        _ => {
            return Err(HttpResponse::BadRequest().json(ErrorResponse {
                error: "Неизвестный клиент (realm).".into(),
            }));
        }
    })
}

async fn register(
    state: web::Data<AppState>,
    http_req: HttpRequest,
    req: web::Json<RegisterRequest>,
) -> impl Responder {
    debug_print!("Register endpoint called");
    if let Err(msg) = password_policy::validate_password(&req.password) {
        return HttpResponse::BadRequest().json(ErrorResponse { error: msg });
    }

    let email = req.email.trim().to_lowercase();
    if email.is_empty() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Укажите email.".into(),
        });
    }

    let realms_grant = match realms_for_registration(&http_req) {
        Ok(r) => r,
        Err(resp) => return resp,
    };

    let nickname = req.nickname.trim();
    if nickname.len() < 2 || nickname.len() > 32 {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Никнейм: от 2 до 32 символов.".into(),
        });
    }

    let email_row = sqlx::query_as::<_, (Uuid, bool)>(
        "SELECT id, email_verified FROM users WHERE lower(trim(email)) = $1",
    )
    .bind(&email)
    .fetch_optional(&state.pool)
    .await;

    match email_row {
        Ok(Some((uid, true))) => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "Этот email уже зарегистрирован. Войдите в личный кабинет.".into(),
            });
        }
        Ok(Some((uid, false))) => {
            if let Err(e) = sqlx::query("DELETE FROM users WHERE id = $1 AND email_verified = false")
                .bind(uid)
                .execute(&state.pool)
                .await
            {
                error!("delete unverified user: {}", e);
            }
        }
        Err(e) => {
            error!("Database error checking email: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
        Ok(None) => {}
    }

    let nick_taken = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM users WHERE lower(trim(nickname)) = lower(trim($1)))",
    )
    .bind(nickname)
    .fetch_one(&state.pool)
    .await;

    match nick_taken {
        Ok(true) => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "Этот никнейм уже занят. Выберите другой.".into(),
            });
        }
        Err(e) => {
            error!("Database error checking nickname: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
        Ok(false) => {}
    }

    let reg_code = email_verification::new_registration_code();
    let hashed = match blocking::bcrypt_hash_password(&req.password).await {
        Ok(h) => h,
        Err(e) => {
            error!("Bcrypt error: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to hash password".into(),
            });
        }
    };

    let phone: Option<String> = req
        .phone
        .as_ref()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());

    if let Some(p) = phone.as_deref() {
        let phone_exists = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM users WHERE phone = $1)",
        )
        .bind(p)
        .fetch_one(&state.pool)
        .await
        .unwrap_or(false);

        if phone_exists {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "Phone already taken".into(),
            });
        }
    }

    let mut tx = match state.pool.begin().await {
        Ok(t) => t,
        Err(e) => {
            error!("tx begin: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    let user_id = match sqlx::query_scalar::<_, Uuid>(
        "INSERT INTO users (email, phone, full_name, nickname, password_hash, settings, email_verified) VALUES ($1, $2, $3, $4, $5, $6, false) RETURNING id",
    )
    .bind(&email)
    .bind(phone)
    .bind(&req.full_name)
    .bind(nickname)
    .bind(hashed)
    .bind(&req.settings)
    .fetch_one(&mut *tx)
    .await {
        Ok(id) => id,
        Err(e) => {
            error!("Failed to insert user: {}", e);
            let _ = tx.rollback().await;
            if format!("{e}").contains("users_nickname") || format!("{e}").contains("nickname") {
                return HttpResponse::BadRequest().json(ErrorResponse {
                    error: "Этот никнейм уже занят. Выберите другой.".into(),
                });
            }
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to create user".into(),
            });
        }
    };

    if let Err(e) = sqlx::query(
        "INSERT INTO registration_log (user_id, email, nickname) VALUES ($1, $2, $3)",
    )
    .bind(user_id)
    .bind(&email)
    .bind(nickname)
    .execute(&mut *tx)
    .await
    {
        error!("registration_log: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to create user".into(),
        });
    }

    if realms_grant.iter().any(|r| *r == "metric" || *r == "nexus") {
        let key_id = Uuid::new_v4();
        let api_key = format!("nx_{}", Uuid::new_v4().as_simple());
        if let Err(e) = sqlx::query(
            "INSERT INTO api_keys (id, user_id, name, key) VALUES ($1, $2, $3, $4)",
        )
        .bind(key_id)
        .bind(user_id)
        .bind("default")
        .bind(&api_key)
        .execute(&mut *tx)
        .await
        {
            error!("api_keys: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to create user".into(),
            });
        }
    }

    if let Err(e) = grant_realms_tx(&mut tx, user_id, &realms_grant).await {
        error!("user_realm: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to create user".into(),
        });
    }

    if let Err(e) = email_verification::insert_pending_code(&mut tx, user_id, &reg_code).await {
        error!("email_verification pending: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to create user".into(),
        });
    }

    if let Err(e) = tx.commit().await {
        error!("commit: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Database error".into(),
        });
    }

    email_verification::spawn_send_registration_code(
        nickname.to_string(),
        email.clone(),
        reg_code,
    );

    HttpResponse::Ok().json(serde_json::json!({
        "status": "pending_verification",
        "message": "Проверьте почту: мы отправили 8-значный код. Без подтверждения вход недоступен.",
        "email": email,
    }))
}

async fn login(
    state: web::Data<AppState>,
    http_req: HttpRequest,
    req: web::Json<LoginRequest>,
) -> impl Responder {
    debug_print!("Login endpoint called");
    let login = req.login.trim();
    let user = sqlx::query_as::<_, (Uuid, String, String, bool, String)>(
        r#"SELECT id, nickname, password_hash, email_verified, email FROM users
           WHERE lower(trim(email)) = lower(trim($1)) OR nickname = $1"#,
    )
    .bind(login)
    .fetch_optional(&state.pool)
    .await;

    let (user_id, nickname, hash, email_verified, account_email) = match user {
        Ok(Some(u)) => u,
        Ok(None) => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid login or password".into(),
            });
        }
        Err(e) => {
            error!("Database error during login: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    let valid = match blocking::bcrypt_verify_password(&req.password, &hash).await {
        Ok(v) => v,
        Err(e) => {
            error!("Bcrypt verify error: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Authentication error".into(),
            });
        }
    };

    if !valid {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid login or password".into(),
        });
    }

    if !email_verified {
        return HttpResponse::Forbidden().json(serde_json::json!({
            "error": "Подтвердите email: введите код из письма или запросите его повторно на странице подтверждения.",
            "error_code": "email_not_verified",
            "email": account_email,
        }));
    }

    if let Some(realm) = client_realm_from_header(&http_req) {
        let mut has = user_has_realm(&state.pool, user_id, realm).await;
        if !has && realm == "metric" && user_has_realm(&state.pool, user_id, "nexus").await {
            if let Err(e) = sqlx::query(
                "INSERT INTO user_realm (user_id, realm) VALUES ($1, 'metric') ON CONFLICT DO NOTHING",
            )
            .bind(user_id)
            .execute(&state.pool)
            .await
            {
                error!("link metric realm for lynx user: {}", e);
            } else {
                has = true;
            }
        }
        if !has {
            let msg = if realm == "metric" {
                "Нет доступа к Waypoint Metric. Зарегистрируйтесь на metrika-waypoint.ru или войдите аккаунтом Lynx (если он уже создан в лаунчере)."
            } else if realm == "roza" {
                "Нет доступа к Roza AI. Создайте аккаунт на waypointclub.ru/roza."
            } else {
                "Нет доступа к Lynx. Зарегистрируйтесь в приложении Lynx Launcher или войдите, если аккаунт уже есть."
            };
            return HttpResponse::Forbidden().json(ErrorResponse {
                error: msg.into(),
            });
        }
    }

    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            error!("JWT_SECRET not set");
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            });
        }
    };

    let ttl = state.config.session_jwt_ttl_hours;
    let token = match create_token(&user_id.to_string(), &jwt_secret, ttl) {
        Ok(t) => t,
        Err(e) => {
            error!("JWT creation error: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to generate token".into(),
            });
        }
    };

    let ingest_api_key: Option<String> =
        sqlx::query_scalar("SELECT key FROM api_keys WHERE user_id = $1 AND name = 'default' LIMIT 1")
            .bind(user_id)
            .fetch_optional(&state.pool)
            .await
            .ok()
            .flatten();

    HttpResponse::Ok()
        .cookie(session::session_cookie(
            &token,
            ttl.max(1) * 3600,
            state.config.session_cookie_secure,
        ))
        .json(AuthResponse {
        token,
        user_id: user_id.to_string(),
        nickname,
        ingest_api_key,
    })
}

async fn logout(state: web::Data<AppState>) -> impl Responder {
    HttpResponse::Ok()
        .cookie(session::clear_session_cookie(
            state.config.session_cookie_secure,
        ))
        .json(serde_json::json!({"ok": true}))
}

async fn link_realm(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<LinkRealmRequest>,
) -> impl Responder {
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            });
        }
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            });
        }
    };

    let realm = body.realm.trim().to_lowercase();
    if realm != "nexus" && realm != "metric" {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "realm must be nexus or metric".into(),
        });
    }

    if user_has_realm(&state.pool, user_id, &realm).await {
        return HttpResponse::Ok().json(serde_json::json!({
            "ok": true,
            "realms": realms_for_user(&state.pool, user_id).await
        }));
    }

    let creds: Option<(String, bool)> =
        sqlx::query_as("SELECT password_hash, email_verified FROM users WHERE id = $1")
            .bind(user_id)
            .fetch_optional(&state.pool)
            .await
            .ok()
            .flatten();

    let Some((hash, email_verified)) = creds else {
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "User not found".into(),
        });
    };

    if !email_verified {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Сначала подтвердите email.".into(),
        });
    }

    let valid = match blocking::bcrypt_verify_password(&body.password, &hash).await {
        Ok(v) => v,
        Err(e) => {
            error!("Bcrypt verify (link_realm): {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Authentication error".into(),
            });
        }
    };

    if !valid {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Неверный пароль".into(),
        });
    }

    if let Err(e) = sqlx::query("INSERT INTO user_realm (user_id, realm) VALUES ($1, $2) ON CONFLICT DO NOTHING")
        .bind(user_id)
        .bind(&realm)
        .execute(&state.pool)
        .await
    {
        error!("link_realm insert: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Database error".into(),
        });
    }

    HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "realms": realms_for_user(&state.pool, user_id).await
    }))
}

async fn realms_for_user(pool: &PgPool, user_id: Uuid) -> Vec<String> {
    sqlx::query_scalar::<_, String>("SELECT realm FROM user_realm WHERE user_id = $1 ORDER BY realm")
        .bind(user_id)
        .fetch_all(pool)
        .await
        .unwrap_or_default()
}

async fn get_profile(
    state: web::Data<AppState>,
    req: HttpRequest,
) -> impl Responder {
    debug_print!("Get profile endpoint called");
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };

    let user = sqlx::query_as::<_, (Uuid, String, Option<String>, String, String, Option<String>, String, chrono::DateTime<chrono::Utc>, serde_json::Value, bool)>(
        "SELECT id, email, phone, full_name, nickname, avatar_url, role, created_at, COALESCE(settings, '{}'::jsonb), email_verified FROM users WHERE id = $1",
    )
    .bind(user_id)
    .fetch_optional(&state.pool)
    .await;

    match user {
        Ok(Some((id, email, phone, full_name, nickname, avatar_url, role, created_at, settings, email_verified))) => {
            let realms = realms_for_user(&state.pool, id).await;
            HttpResponse::Ok().json(UserProfileResponse {
                id: id.to_string(),
                email,
                phone,
                full_name,
                nickname,
                avatar_url,
                role: Some(role),
                created_at,
                settings,
                realms,
                email_verified,
            })
        }
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "User not found".into(),
        }),
        Err(e) => {
            error!("Database error: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

async fn update_profile(
    state: web::Data<AppState>,
    req: HttpRequest,
    payload: web::Json<UpdateProfileRequest>,
) -> impl Responder {
    debug_print!("Update profile endpoint called");
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };

    if let Some(full_name) = &payload.full_name {
        if let Err(e) = sqlx::query("UPDATE users SET full_name = $1 WHERE id = $2")
            .bind(full_name)
            .bind(user_id)
            .execute(&state.pool)
            .await
        {
            error!("Failed to update full_name: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update profile".into(),
            });
        }
    }

    if let Some(avatar_url) = &payload.avatar_url {
        if let Err(e) = sqlx::query("UPDATE users SET avatar_url = $1 WHERE id = $2")
            .bind(avatar_url)
            .bind(user_id)
            .execute(&state.pool)
            .await
        {
            error!("Failed to update avatar_url: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update profile".into(),
            });
        }
    }

    if let Some(settings) = &payload.settings {
        if let Err(e) = sqlx::query("UPDATE users SET settings = $1 WHERE id = $2")
            .bind(settings)
            .bind(user_id)
            .execute(&state.pool)
            .await
        {
            error!("Failed to update settings: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update profile".into(),
            });
        }
    }

    HttpResponse::Ok().json(serde_json::json!({"message": "Profile updated"}))
}

async fn upload_profile_avatar(
    state: web::Data<AppState>,
    req: HttpRequest,
    mut payload: Multipart,
) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };

    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let mut file_bytes = Vec::<u8>::new();
    let mut original_filename: Option<String> = None;
    let mut total_read: usize = 0;
    let max_bytes: usize = 2 * 1024 * 1024; // 2MB

    while let Some(Ok(mut field)) = payload.next().await {
        let cd = field.content_disposition().cloned();
        let field_name = cd.as_ref().and_then(|c| Some(c.get_name().unwrap_or(""))).unwrap_or("");
        if field_name != "file" {
            continue;
        }

        if let Some(ref c) = cd {
            if let Some(filename) = c.get_filename() {
                original_filename = Some(filename.to_string());
            }
        }

        while let Some(Ok(chunk)) = field.next().await {
            total_read = total_read.saturating_add(chunk.len());
            if total_read > max_bytes {
                return HttpResponse::BadRequest().json(ErrorResponse {
                    error: "Avatar too large (max 2MB)".into(),
                });
            }
            file_bytes.extend_from_slice(&chunk);
        }
    }

    if file_bytes.is_empty() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "File is required".into(),
        });
    }

    let ext = original_filename
        .as_deref()
        .and_then(|f| Path::new(f).extension().and_then(|e| e.to_str()))
        .map(|s| s.to_lowercase())
        .filter(|s| matches!(s.as_str(), "png" | "jpg" | "jpeg" | "gif" | "webp"))
        .unwrap_or_else(|| "png".into());

    let avatars_dir = PathBuf::from(format!("./uploads/avatars/{}", user_id));
    let stored_name = format!("{}.{}", Uuid::new_v4(), ext);
    let full_path = format!("{}/{}", avatars_dir.display(), stored_name);

    if let Err(e) = blocking::write_upload_file(Some(avatars_dir.clone()), full_path.clone(), file_bytes).await {
        error!("upload_profile_avatar write file: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to write file".into(),
        });
    }

    let conn_info = req.connection_info();
    let scheme = conn_info.scheme();
    let host = conn_info.host();
    let avatar_url = format!("{}://{}/avatars/{}/{}", scheme, host, user_id, stored_name);

    if let Err(e) = sqlx::query("UPDATE users SET avatar_url = $1 WHERE id = $2")
        .bind(&avatar_url)
        .bind(user_id)
        .execute(&state.pool)
        .await
    {
        error!("upload_profile_avatar db update: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to update avatar".into(),
        });
    }

    HttpResponse::Ok().json(serde_json::json!({ "avatar_url": avatar_url }))
}

async fn serve_avatar(
    req: HttpRequest,
    path: web::Path<(Uuid, String)>,
) -> impl Responder {
    let _ = req; // на будущее: можно добавить rate-limit / логирование
    let (user_id, filename) = path.into_inner();

    if filename.contains('/') || filename.contains('\\') || filename.contains("..") {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid filename".into(),
        });
    }

    let ext = Path::new(&filename)
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();

    let content_type = match ext.as_str() {
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "webp" => "image/webp",
        _ => "application/octet-stream",
    };

    let full_path = format!("./uploads/avatars/{}/{}", user_id, filename);
    match blocking::read_file_bytes(full_path).await {
        Ok(data) => HttpResponse::Ok().content_type(content_type).body(data),
        Err(e) => {
            if e.kind() == std::io::ErrorKind::NotFound {
                HttpResponse::NotFound().json(ErrorResponse {
                    error: "File not found".into(),
                })
            } else {
                HttpResponse::InternalServerError().json(ErrorResponse {
                    error: "Failed to read file".into(),
                })
            }
        }
    }
}

async fn create_project(
    state: web::Data<AppState>,
    req: HttpRequest,
    payload: web::Json<CreateProjectRequest>,
) -> impl Responder {
    debug_print!("Create project endpoint called");
    let jwt_secret = env::var("JWT_SECRET").unwrap();
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };

    let project_id = Uuid::new_v4();
    let root_folder = format!("{}", project_id);
    let vis = payload.visibility.as_deref().unwrap_or("private");
    let share_slug = if vis == "link" {
        Some(format!("nx{}", Uuid::new_v4().as_simple()))
    } else {
        None
    };

    let result = sqlx::query(
        "INSERT INTO projects (id, owner_id, name, description, visibility, root_folder, share_slug) VALUES ($1, $2, $3, $4, $5, $6, $7)"
    )
    .bind(project_id)
    .bind(user_id)
    .bind(&payload.name)
    .bind(&payload.description)
    .bind(vis)
    .bind(&root_folder)
    .bind(&share_slug)
    .execute(&state.pool)
    .await;

    match result {
        Ok(_) => {
            if let Err(e) = ensure_project_root(&project_id) {
                error!("Failed to create project root folder: {}", e);
                return HttpResponse::InternalServerError().json(ErrorResponse {
                    error: "Failed to create project directory".into(),
                });
            }
            HttpResponse::Ok().json(ProjectResponse {
                id: project_id.to_string(),
                owner_id: user_id.to_string(),
                name: payload.name.clone(),
                description: payload.description.clone(),
                visibility: vis.to_string(),
                root_folder: Some(root_folder),
                share_slug,
                my_role: Some("owner".into()),
                created_at: Utc::now(),
                updated_at: Utc::now(),
            })
        }
        Err(e) => {
            error!("Failed to create project: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to create project".into(),
            })
        }
    }
}

async fn get_projects(
    state: web::Data<AppState>,
    req: HttpRequest,
) -> impl Responder {
    debug_print!("Get projects endpoint called");
    let jwt_secret = env::var("JWT_SECRET").unwrap();
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };

    let projects = sqlx::query_as::<_, (Uuid, Uuid, String, Option<String>, String, Option<String>, Option<String>, chrono::DateTime<chrono::Utc>, chrono::DateTime<chrono::Utc>)>(
        r#"SELECT p.id, p.owner_id, p.name, p.description, p.visibility, p.root_folder, p.share_slug, p.created_at, p.updated_at
           FROM projects p
           WHERE p.owner_id = $1
           UNION
           SELECT p.id, p.owner_id, p.name, p.description, p.visibility, p.root_folder, p.share_slug, p.created_at, p.updated_at
           FROM projects p
           INNER JOIN project_link_members m ON m.project_id = p.id AND m.user_id = $1
           ORDER BY updated_at DESC"#,
    )
    .bind(user_id)
    .bind(user_id)
    .fetch_all(&state.pool)
    .await;

    match projects {
        Ok(rows) => {
            let response: Vec<ProjectResponse> = rows
                .into_iter()
                .map(|(id, owner_id, name, description, visibility, root_folder, share_slug, created_at, updated_at)| {
                    let my_role = if owner_id == user_id {
                        Some("owner".into())
                    } else {
                        Some("viewer".into())
                    };
                    ProjectResponse {
                        id: id.to_string(),
                        owner_id: owner_id.to_string(),
                        name,
                        description,
                        visibility,
                        root_folder,
                        share_slug,
                        my_role,
                        created_at,
                        updated_at,
                    }
                })
                .collect();
            HttpResponse::Ok().json(response)
        }
        Err(e) => {
            error!("Failed to fetch projects: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to fetch projects".into(),
            })
        }
    }
}

async fn upload_asset(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
    mut payload: Multipart,
) -> impl Responder {
    debug_print!("Upload asset endpoint called");
    let jwt_secret = env::var("JWT_SECRET").unwrap();
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };

    let project_id = path.into_inner();

    let can_write = match access::user_can_write_project(&state.pool, user_id, project_id).await {
        Ok(v) => v,
        Err(e) => {
            error!("access check: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };
    if !can_write {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let mut asset_name = None;
    let mut asset_type = None;
    let mut metadata = None;
    let mut file_data = Vec::new();
    let mut file_extension = String::new();

    while let Some(Ok(mut field)) = payload.next().await {
        let cd = field.content_disposition().cloned();
        let field_name = cd.as_ref().and_then(|c| Some(c.get_name().unwrap_or(""))).unwrap_or("");

        match field_name {
            "name" => {
                while let Some(Ok(chunk)) = field.next().await {
                    asset_name = Some(String::from_utf8_lossy(&chunk).to_string());
                }
            }
            "type" => {
                while let Some(Ok(chunk)) = field.next().await {
                    asset_type = Some(String::from_utf8_lossy(&chunk).to_string());
                }
            }
            "metadata" => {
                while let Some(Ok(chunk)) = field.next().await {
                    metadata = Some(serde_json::from_slice(&chunk).unwrap_or(serde_json::Value::Null));
                }
            }
            "file" => {
                if let Some(ref c) = cd {
                    if let Some(filename) = c.get_filename() {
                        file_extension = Path::new(filename)
                            .extension()
                            .unwrap_or_default()
                            .to_string_lossy()
                            .to_string();
                    }
                }
                while let Some(Ok(chunk)) = field.next().await {
                    file_data.extend_from_slice(&chunk);
                }
            }
            _ => {}
        }
    }

    let asset_name = match asset_name {
        Some(name) if !name.is_empty() => name,
        _ => return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Asset name is required".into(),
        }),
    };
    let asset_type = match asset_type {
        Some(t) if !t.is_empty() => t,
        _ => return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Asset type is required".into(),
        }),
    };
    if file_data.is_empty() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "File is required".into(),
        });
    }

    let mut hasher = Sha256::new();
    hasher.update(&file_data);
    let hash = format!("{:x}", hasher.finalize());

    let asset_id = Uuid::new_v4();
    let file_name = format!("{}_{}.{}", asset_id, asset_name, file_extension);
    let storage_path = format!("{}/{}", project_id, file_name);
    let full_path = format!("./uploads/{}", storage_path);
    let parent_dirs: Option<PathBuf> = Path::new(&full_path).parent().map(|p| p.to_path_buf());

    if let Err(e) = blocking::write_upload_file(parent_dirs, full_path.clone(), file_data.clone()).await {
        error!("Failed to write file: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to save file".into(),
        });
    }

    let insert_result = sqlx::query(
        "INSERT INTO assets (id, project_id, name, type, size, hash, storage_path, metadata, created_by) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)"
    )
    .bind(asset_id)
    .bind(project_id)
    .bind(&asset_name)
    .bind(&asset_type)
    .bind(file_data.len() as i64)
    .bind(&hash)
    .bind(&storage_path)
    .bind(metadata.unwrap_or(serde_json::Value::Null))
    .bind(user_id)
    .execute(&state.pool)
    .await;

    match insert_result {
        Ok(_) => {
            let body = serde_json::json!({
                "id": asset_id.to_string(),
                "name": asset_name,
                "type": asset_type,
                "size": file_data.len(),
                "hash": hash,
                "storage_path": storage_path,
            });
            state.studio_collab.broadcast_json(project_id, serde_json::json!({
                "type": "nexus_asset_created",
                "projectId": project_id.to_string(),
                "assetId": asset_id.to_string(),
                "assetType": asset_type,
                "name": asset_name,
            }));
            HttpResponse::Ok().json(body)
        }
        Err(e) => {
            error!("Failed to insert asset: {}", e);
            blocking::remove_file(full_path).await;
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to save asset metadata".into(),
            })
        }
    }
}

async fn get_assets(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    debug_print!("Get assets endpoint called");
    let jwt_secret = env::var("JWT_SECRET").unwrap();
    let user_id = get_user_id_from_token(&req, &jwt_secret);

    let project_id = path.into_inner();

    let can_read = match access::user_can_read_project(&state.pool, user_id, project_id).await {
        Ok(v) => v,
        Err(e) => {
            error!("access read: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };
    if !can_read {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let assets = sqlx::query_as::<_, (Uuid, String, String, Option<i64>, Option<String>, Option<String>, serde_json::Value, Option<Uuid>, chrono::DateTime<chrono::Utc>, chrono::DateTime<chrono::Utc>)>(
        "SELECT id, name, type, size, hash, storage_path, metadata, created_by, created_at, updated_at FROM assets WHERE project_id = $1"
    )
    .bind(project_id)
    .fetch_all(&state.pool)
    .await;

    match assets {
        Ok(rows) => {
            let response: Vec<AssetResponse> = rows
                .into_iter()
                .map(|(id, name, r#type, size, hash, storage_path, metadata, created_by, created_at, updated_at)| AssetResponse {
                    id: id.to_string(),
                    project_id: project_id.to_string(),
                    name,
                    r#type,
                    size,
                    hash,
                    storage_path,
                    metadata,
                    created_by: created_by.map(|u| u.to_string()),
                    created_at,
                    updated_at,
                })
                .collect();
            HttpResponse::Ok().json(response)
        }
        Err(e) => {
            error!("Failed to fetch assets: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to fetch assets".into(),
            })
        }
    }
}

async fn download_asset(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    debug_print!("Download asset endpoint called");
    let jwt_secret = env::var("JWT_SECRET").unwrap();
    let user_id = get_user_id_from_token(&req, &jwt_secret);

    let asset_id = path.into_inner();

    let asset_info: Option<(String, Uuid, String)> = sqlx::query_as(
        "SELECT storage_path, project_id, visibility 
         FROM assets 
         JOIN projects ON assets.project_id = projects.id 
         WHERE assets.id = $1"
    )
    .bind(asset_id)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    let (storage_path, project_id, _visibility) = match asset_info {
        Some((p, pid, vis)) => (p, pid, vis),
        None => return HttpResponse::NotFound().json(ErrorResponse {
            error: "Asset not found".into(),
        }),
    };

    let can_read = match access::user_can_read_project(&state.pool, user_id, project_id).await {
        Ok(v) => v,
        Err(e) => {
            error!("download access: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };
    if !can_read {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let full_path = format!("./uploads/{}", storage_path);

    match blocking::read_file_bytes(full_path).await {
        Ok(data) => HttpResponse::Ok()
            .content_type("application/octet-stream")
            .body(data),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            error!("File not found: {}", e);
            HttpResponse::NotFound().json(ErrorResponse {
                error: "File not found".into(),
            })
        }
        Err(e) => {
            error!("Failed to read file: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to read file".into(),
            })
        }
    }
}

async fn put_project_asset_content(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<(Uuid, Uuid)>,
    body: web::Bytes,
) -> impl Responder {
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let (project_id, asset_id) = path.into_inner();

    let can_write = match access::user_can_write_project(&state.pool, user_id, project_id).await {
        Ok(v) => v,
        Err(e) => {
            error!("put asset access: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };
    if !can_write {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let storage_row: Option<(String,)> =
        sqlx::query_as("SELECT storage_path FROM assets WHERE id = $1 AND project_id = $2")
            .bind(asset_id)
            .bind(project_id)
            .fetch_optional(&state.pool)
            .await
            .unwrap_or(None);

    let storage_path = match storage_row {
        Some((p,)) if !p.is_empty() => p,
        _ => {
            return HttpResponse::NotFound().json(ErrorResponse {
                error: "Asset not found".into(),
            })
        }
    };

    let full_path = format!("./uploads/{}", storage_path);
    let parent_dirs: Option<PathBuf> = Path::new(&full_path).parent().map(|p| p.to_path_buf());
    let bytes = body.to_vec();

    if let Err(e) = blocking::write_upload_file(parent_dirs, full_path.clone(), bytes.clone()).await {
        error!("put asset write: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to write file".into(),
        });
    }

    let mut hasher = Sha256::new();
    hasher.update(&bytes);
    let hash = format!("{:x}", hasher.finalize());
    let size = bytes.len() as i64;

    let upd = sqlx::query(
        "UPDATE assets SET size = $1, hash = $2, updated_at = NOW() WHERE id = $3 AND project_id = $4",
    )
    .bind(size)
    .bind(&hash)
    .bind(asset_id)
    .bind(project_id)
    .execute(&state.pool)
    .await;

    if let Err(e) = upd {
        error!("put asset db: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to update asset metadata".into(),
        });
    }

    let payload = serde_json::json!({
        "type": "nexus_asset_updated",
        "projectId": project_id.to_string(),
        "assetId": asset_id.to_string(),
        "hash": hash,
        "size": size,
        "updatedBy": user_id.to_string(),
    });
    state.studio_collab.broadcast_json(project_id, payload.clone());

    HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "hash": hash,
        "size": size,
        "broadcast": payload,
    }))
}

async fn admin_keys_create(
    state: web::Data<AppState>,
    req: HttpRequest,
    payload: web::Json<AdminKeyCreateRequest>,
) -> impl Responder {
    let user_id = match authz::require_nexus(&state.pool, &req).await {
        Ok(id) => id,
        Err(resp) => return resp,
    };

    let raw_key = generate_admin_activation_key();
    let key_hash = hash_admin_activation_key(&raw_key);
    let key_prefix = raw_key[..8].to_string();
    let expires_at = payload
        .expires_in_days
        .filter(|d| *d > 0)
        .map(|d| Utc::now() + Duration::days(d));
    let key_kind = match payload.key_kind.as_deref() {
        Some("nexus") => "nexus",
        _ => "admin",
    };

    let row = sqlx::query_as::<_, (Uuid, chrono::DateTime<chrono::Utc>)>(
        "INSERT INTO admin_activation_keys (key_hash, key_prefix, note, created_by, expires_at, key_kind, pool_generated)
         VALUES ($1, $2, $3, $4, $5, $6, false)
         RETURNING id, created_at",
    )
    .bind(&key_hash)
    .bind(&key_prefix)
    .bind(payload.note.as_ref().map(|s| s.trim()).filter(|s| !s.is_empty()))
    .bind(user_id)
    .bind(expires_at)
    .bind(key_kind)
    .fetch_one(&state.pool)
    .await;

    match row {
        Ok((id, created_at)) => HttpResponse::Ok().json(AdminKeyCreateResponse {
            id: id.to_string(),
            key: raw_key,
            key_prefix,
            expires_at,
            created_at,
        }),
        Err(e) => {
            error!("admin_keys_create: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to create admin key".into(),
            })
        }
    }
}

async fn admin_keys_list(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    if let Err(resp) = authz::require_nexus(&state.pool, &req).await {
        return resp;
    }

    let rows = sqlx::query_as::<
        _,
        (
            Uuid,
            String,
            Option<String>,
            Option<Uuid>,
            chrono::DateTime<chrono::Utc>,
            Option<chrono::DateTime<chrono::Utc>>,
            Option<chrono::DateTime<chrono::Utc>>,
            Option<chrono::DateTime<chrono::Utc>>,
            Option<String>,
            String,
            bool,
        ),
    >(
        "SELECT k.id,
                k.key_prefix,
                k.note,
                k.created_by,
                k.created_at,
                k.expires_at,
                k.used_at,
                k.revoked_at,
                u.email,
                k.key_kind,
                k.pool_generated
         FROM admin_activation_keys k
         LEFT JOIN users u ON u.id = k.used_by
         ORDER BY k.created_at DESC
         LIMIT 200",
    )
    .fetch_all(&state.pool)
    .await;

    match rows {
        Ok(items) => {
            let out: Vec<AdminKeyItemResponse> = items
                .into_iter()
                .map(
                    |(id, key_prefix, note, created_by, created_at, expires_at, used_at, revoked_at, used_by_email, key_kind, pool_generated)| {
                        AdminKeyItemResponse {
                            id: id.to_string(),
                            key_prefix,
                            note,
                            created_by: created_by.map(|u| u.to_string()),
                            created_at,
                            expires_at,
                            used_at,
                            revoked_at,
                            used_by_email,
                            key_kind,
                            pool_generated,
                        }
                    },
                )
                .collect();
            HttpResponse::Ok().json(out)
        }
        Err(e) => {
            error!("admin_keys_list: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to read admin keys".into(),
            })
        }
    }
}

async fn activate_admin_by_key(
    state: web::Data<AppState>,
    req: HttpRequest,
    payload: web::Json<AdminActivateRequest>,
) -> impl Responder {
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let key = payload.key.trim();
    if key.len() != 60 {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Admin key must be exactly 60 characters".into(),
        });
    }

    if is_admin(&state.pool, user_id).await {
        return HttpResponse::Ok().json(serde_json::json!({
            "ok": true,
            "role": "admin",
            "message": "User already has admin role"
        }));
    }

    let key_hash = hash_admin_activation_key(key);
    let mut tx = match state.pool.begin().await {
        Ok(t) => t,
        Err(e) => {
            error!("activate_admin_by_key tx begin: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    let active_key = sqlx::query_as::<_, (Uuid,)>(
        "SELECT id
         FROM admin_activation_keys
         WHERE key_hash = $1
           AND key_kind = 'admin'
           AND used_at IS NULL
           AND revoked_at IS NULL
           AND (expires_at IS NULL OR expires_at > now())
         FOR UPDATE",
    )
    .bind(&key_hash)
    .fetch_optional(&mut *tx)
    .await;

    let Some((key_id,)) = (match active_key {
        Ok(v) => v,
        Err(e) => {
            error!("activate_admin_by_key select key: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    }) else {
        let _ = tx.rollback().await;
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Admin key is invalid, expired, or already used".into(),
        });
    };

    if let Err(e) = sqlx::query("UPDATE users SET role = 'admin' WHERE id = $1")
        .bind(user_id)
        .execute(&mut *tx)
        .await
    {
        error!("activate_admin_by_key update user: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to update user role".into(),
        });
    }

    if let Err(e) = sqlx::query(
        "UPDATE admin_activation_keys
         SET used_by = $1, used_at = now()
         WHERE id = $2",
    )
    .bind(user_id)
    .bind(key_id)
    .execute(&mut *tx)
    .await
    {
        error!("activate_admin_by_key update key: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to activate admin key".into(),
        });
    }

    if let Err(e) = tx.commit().await {
        error!("activate_admin_by_key commit: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Database error".into(),
        });
    }

    HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "role": "admin",
        "message": "Admin access activated"
    }))
}

async fn activate_nexus_by_key(
    state: web::Data<AppState>,
    req: HttpRequest,
    payload: web::Json<AdminActivateRequest>,
) -> impl Responder {
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let key = payload.key.trim();
    if key.len() != 60 {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Engine access key must be exactly 60 characters".into(),
        });
    }

    if is_nexus(&state.pool, user_id).await {
        return HttpResponse::Ok().json(serde_json::json!({
            "ok": true,
            "role": "nexus",
            "message": "User already has engine (Lynx launcher) access"
        }));
    }

    let key_hash = hash_admin_activation_key(key);
    let mut tx = match state.pool.begin().await {
        Ok(t) => t,
        Err(e) => {
            error!("activate_nexus_by_key tx begin: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    let active_key = sqlx::query_as::<_, (Uuid,)>(
        "SELECT id
         FROM admin_activation_keys
         WHERE key_hash = $1
           AND key_kind = 'nexus'
           AND used_at IS NULL
           AND revoked_at IS NULL
           AND (expires_at IS NULL OR expires_at > now())
         FOR UPDATE",
    )
    .bind(&key_hash)
    .fetch_optional(&mut *tx)
    .await;

    let Some((key_id,)) = (match active_key {
        Ok(v) => v,
        Err(e) => {
            error!("activate_nexus_by_key select key: {}", e);
            let _ = tx.rollback().await;
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    }) else {
        let _ = tx.rollback().await;
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Engine access key is invalid, expired, or already used".into(),
        });
    };

    if let Err(e) = sqlx::query("UPDATE users SET role = 'nexus' WHERE id = $1")
        .bind(user_id)
        .execute(&mut *tx)
        .await
    {
        error!("activate_nexus_by_key update user: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to update user role".into(),
        });
    }

    if let Err(e) = sqlx::query(
        "UPDATE admin_activation_keys
         SET used_by = $1, used_at = now()
         WHERE id = $2",
    )
    .bind(user_id)
    .bind(key_id)
    .execute(&mut *tx)
    .await
    {
        error!("activate_nexus_by_key update key: {}", e);
        let _ = tx.rollback().await;
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to activate engine access key".into(),
        });
    }

    if let Err(e) = tx.commit().await {
        error!("activate_nexus_by_key commit: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Database error".into(),
        });
    }

    HttpResponse::Ok().json(serde_json::json!({
        "ok": true,
        "role": "nexus",
        "message": "Lynx engine access activated"
    }))
}

async fn admin_login(
    state: web::Data<AppState>,
    req: web::Json<AdminLoginRequest>,
) -> impl Responder {
    debug_print!("Admin login endpoint called");
    let user = sqlx::query_as::<_, (Uuid, String, String, String)>(
        "SELECT id, nickname, password_hash, role FROM users WHERE email = $1 OR nickname = $1"
    )
    .bind(&req.login)
    .fetch_optional(&state.pool)
    .await;

    let (user_id, _nickname, hash, role) = match user {
        Ok(Some(u)) => u,
        Ok(None) => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid login or password".into(),
            });
        }
        Err(e) => {
            error!("Database error during admin login: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            });
        }
    };

    if role != "admin" && role != "nexus" {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied: not an administrator".into(),
        });
    }

    let valid = match blocking::bcrypt_verify_password(&req.password, &hash).await {
        Ok(v) => v,
        Err(e) => {
            error!("Bcrypt verify error: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Authentication error".into(),
            });
        }
    };

    if !valid {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid login or password".into(),
        });
    }

    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            error!("JWT_SECRET not set");
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            });
        }
    };

    let ttl = state.config.session_jwt_ttl_hours;
    let token = match create_token(&user_id.to_string(), &jwt_secret, ttl) {
        Ok(t) => t,
        Err(e) => {
            error!("JWT creation error: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to generate token".into(),
            });
        }
    };

    HttpResponse::Ok()
        .cookie(session::session_cookie(
            &token,
            ttl.max(1) * 3600,
            state.config.session_cookie_secure,
        ))
        .json(AdminAuthResponse {
        token,
        user_id: user_id.to_string(),
        role,
    })
}

async fn admin_registration_status(state: web::Data<AppState>) -> impl Responder {
    HttpResponse::Ok().json(serde_json::json!({
        "open": state.config.admin_open_registration
    }))
}

async fn admin_register(state: web::Data<AppState>) -> impl Responder {
    let _ = state;
    HttpResponse::Forbidden().json(ErrorResponse {
        error: "Admin self-registration disabled. Use /auth/admin/activate with a 60-char key."
            .into(),
    })
}

async fn admin_stats(
    state: web::Data<AppState>,
    req: HttpRequest,
) -> impl Responder {
    debug_print!("Admin stats endpoint called");
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };
    if !is_admin(&state.pool, user_id).await {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let users_count: Result<Option<(i64,)>, _> = sqlx::query_as("SELECT COUNT(*) FROM users")
        .fetch_optional(&state.pool)
        .await;
    let projects_count: Result<Option<(i64,)>, _> = sqlx::query_as("SELECT COUNT(*) FROM projects")
        .fetch_optional(&state.pool)
        .await;
    let assets_count: Result<Option<(i64,)>, _> = sqlx::query_as("SELECT COUNT(*) FROM assets")
        .fetch_optional(&state.pool)
        .await;

    let active_sessions = 0;

    HttpResponse::Ok().json(StatsResponse {
        users: users_count.unwrap_or(Some((0,))).unwrap().0,
        projects: projects_count.unwrap_or(Some((0,))).unwrap().0,
        assets: assets_count.unwrap_or(Some((0,))).unwrap().0,
        active_sessions,
    })
}

async fn admin_metrics(
    state: web::Data<AppState>,
    req: HttpRequest,
) -> impl Responder {
    debug_print!("Admin metrics endpoint called");
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };
    if !is_admin(&state.pool, user_id).await {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let metrics = state.metrics.lock().await;
    let points = metrics.get_points();
    HttpResponse::Ok().json(points)
}

async fn admin_users(
    state: web::Data<AppState>,
    req: HttpRequest,
) -> impl Responder {
    debug_print!("Admin users endpoint called");
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };
    if !is_admin(&state.pool, user_id).await {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let users = sqlx::query_as::<_, (Uuid, String, Option<String>, String, String, Option<String>, String, bool, i64, chrono::DateTime<chrono::Utc>, chrono::DateTime<chrono::Utc>)>(
        "SELECT id, email, phone, full_name, nickname, avatar_url, role, blocked, coins, created_at, updated_at FROM users"
    )
    .fetch_all(&state.pool)
    .await;

    match users {
        Ok(rows) => {
            let response: Vec<AdminUserResponse> = rows
                .into_iter()
                .map(|(id, email, phone, full_name, nickname, avatar_url, role, blocked, coins, created_at, updated_at)| AdminUserResponse {
                    id: id.to_string(),
                    email,
                    phone,
                    full_name,
                    nickname,
                    avatar_url,
                    role,
                    blocked,
                    coins,
                    created_at,
                    updated_at,
                })
                .collect();
            HttpResponse::Ok().json(response)
        }
        Err(e) => {
            error!("Failed to fetch users: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to fetch users".into(),
            })
        }
    }
}

async fn admin_update_user(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
    payload: web::Json<UpdateUserRequest>,
) -> impl Responder {
    debug_print!("Admin update user endpoint called");
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let admin_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };
    if !is_admin(&state.pool, admin_id).await {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let target_user_id = path.into_inner();

    if let Some(full_name) = &payload.full_name {
        if let Err(e) = sqlx::query("UPDATE users SET full_name = $1 WHERE id = $2")
            .bind(full_name)
            .bind(target_user_id)
            .execute(&state.pool)
            .await
        {
            error!("Failed to update user full_name: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update user".into(),
            });
        }
    }

    if let Some(role) = &payload.role {
        if role != "user" && role != "admin" && role != "nexus" {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "Invalid role. Allowed: user, admin, nexus".into(),
            });
        }
        if let Err(e) = sqlx::query("UPDATE users SET role = $1 WHERE id = $2")
            .bind(role)
            .bind(target_user_id)
            .execute(&state.pool)
            .await
        {
            error!("Failed to update user role: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update user".into(),
            });
        }
    }

    if let Some(coins) = payload.coins {
        if let Err(e) = sqlx::query("UPDATE users SET coins = $1 WHERE id = $2")
            .bind(coins as i64)
            .bind(target_user_id)
            .execute(&state.pool)
            .await
        {
            error!("Failed to update user coins: {}", e);
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to update user".into(),
            });
        }
    }

    HttpResponse::Ok().json(serde_json::json!({"message": "User updated"}))
}

async fn admin_block_user(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
    payload: web::Json<BlockUserRequest>,
) -> impl Responder {
    debug_print!("Admin block user endpoint called");
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let admin_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };
    if !is_admin(&state.pool, admin_id).await {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let target_user_id = path.into_inner();

    if let Err(e) = sqlx::query("UPDATE users SET blocked = $1 WHERE id = $2")
        .bind(payload.blocked)
        .bind(target_user_id)
        .execute(&state.pool)
        .await
    {
        error!("Failed to update user block status: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to update user".into(),
        });
    }

    HttpResponse::Ok().json(serde_json::json!({"message": "User block status updated"}))
}

async fn admin_delete_user(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    debug_print!("Admin delete user endpoint called");
    if let Err(resp) = authz::require_nexus(&state.pool, &req).await {
        return resp;
    }

    let target_user_id = path.into_inner();

    if let Err(e) = sqlx::query("DELETE FROM users WHERE id = $1")
        .bind(target_user_id)
        .execute(&state.pool)
        .await
    {
        error!("Failed to delete user: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to delete user".into(),
        });
    }

    HttpResponse::Ok().json(serde_json::json!({"message": "User deleted"}))
}

async fn admin_projects(
    state: web::Data<AppState>,
    req: HttpRequest,
) -> impl Responder {
    debug_print!("Admin projects endpoint called");
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };
    if !is_admin(&state.pool, user_id).await {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let projects = sqlx::query_as::<_, (Uuid, Uuid, String, Option<String>, String, Option<String>, chrono::DateTime<chrono::Utc>, chrono::DateTime<chrono::Utc>)>(
        "SELECT id, owner_id, name, description, visibility, root_folder, created_at, updated_at FROM projects"
    )
    .fetch_all(&state.pool)
    .await;

    match projects {
        Ok(rows) => {
            let mut response = Vec::new();
            for (id, owner_id, name, description, visibility, root_folder, created_at, updated_at) in rows {
                let owner_name: Option<(String,)> = sqlx::query_as("SELECT nickname FROM users WHERE id = $1")
                    .bind(owner_id)
                    .fetch_optional(&state.pool)
                    .await
                    .unwrap_or(None);
                let asset_count: Option<(i64,)> = sqlx::query_as("SELECT COUNT(*) FROM assets WHERE project_id = $1")
                    .bind(id)
                    .fetch_optional(&state.pool)
                    .await
                    .unwrap_or(None);
                response.push(AdminProjectResponse {
                    id: id.to_string(),
                    owner_id: owner_id.to_string(),
                    owner_name: owner_name.map(|(n,)| n),
                    name,
                    description,
                    visibility,
                    root_folder,
                    created_at,
                    updated_at,
                    asset_count: asset_count.map(|(c,)| c),
                });
            }
            HttpResponse::Ok().json(response)
        }
        Err(e) => {
            error!("Failed to fetch projects: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to fetch projects".into(),
            })
        }
    }
}

async fn admin_delete_project(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    debug_print!("Admin delete project endpoint called");
    if let Err(resp) = authz::require_nexus(&state.pool, &req).await {
        return resp;
    }

    let project_id = path.into_inner();

    if let Err(e) = sqlx::query("DELETE FROM projects WHERE id = $1")
        .bind(project_id)
        .execute(&state.pool)
        .await
    {
        error!("Failed to delete project: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to delete project".into(),
        });
    }

    let _ = fs::remove_dir_all(format!("./uploads/{}", project_id));

    HttpResponse::Ok().json(serde_json::json!({"message": "Project deleted"}))
}

async fn admin_assets(
    state: web::Data<AppState>,
    req: HttpRequest,
) -> impl Responder {
    debug_print!("Admin assets endpoint called");
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };
    if !is_admin(&state.pool, user_id).await {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let assets = sqlx::query_as::<_, (Uuid, Uuid, String, String, Option<i64>, Option<String>, Option<String>, Option<Uuid>, chrono::DateTime<chrono::Utc>, chrono::DateTime<chrono::Utc>)>(
        "SELECT id, project_id, name, type, size, hash, storage_path, created_by, created_at, updated_at FROM assets"
    )
    .fetch_all(&state.pool)
    .await;

    match assets {
        Ok(rows) => {
            let mut response = Vec::new();
            for (id, project_id, name, r#type, size, hash, storage_path, created_by, created_at, updated_at) in rows {
                let project_name: Option<(String,)> = sqlx::query_as("SELECT name FROM projects WHERE id = $1")
                    .bind(project_id)
                    .fetch_optional(&state.pool)
                    .await
                    .unwrap_or(None);
                response.push(AdminAssetResponse {
                    id: id.to_string(),
                    project_id: project_id.to_string(),
                    project_name: project_name.map(|(n,)| n),
                    name,
                    r#type,
                    size,
                    hash,
                    storage_path,
                    created_by: created_by.map(|u| u.to_string()),
                    created_at,
                    updated_at,
                });
            }
            HttpResponse::Ok().json(response)
        }
        Err(e) => {
            error!("Failed to fetch assets: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to fetch assets".into(),
            })
        }
    }
}

async fn admin_delete_asset(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    debug_print!("Admin delete asset endpoint called");
    if let Err(resp) = authz::require_nexus(&state.pool, &req).await {
        return resp;
    }

    let asset_id = path.into_inner();

    let asset_info: Option<(String,)> = sqlx::query_as("SELECT storage_path FROM assets WHERE id = $1")
        .bind(asset_id)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None);

    if let Err(e) = sqlx::query("DELETE FROM assets WHERE id = $1")
        .bind(asset_id)
        .execute(&state.pool)
        .await
    {
        error!("Failed to delete asset: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to delete asset".into(),
        });
    }

    if let Some((storage_path,)) = asset_info {
        let full_path = format!("./uploads/{}", storage_path);
        let _ = fs::remove_file(full_path);
    }

    HttpResponse::Ok().json(serde_json::json!({"message": "Asset deleted"}))
}

async fn admin_db_query(
    state: web::Data<AppState>,
    req: HttpRequest,
    payload: web::Json<DbQueryRequest>,
) -> impl Responder {
    debug_print!("Admin DB query endpoint called");
    if let Err(resp) = authz::require_nexus(&state.pool, &req).await {
        return resp;
    }

    let query = payload.query.trim();
    let read_only = payload.read_only;

    if let Err(msg) = admin_sql::validate_admin_query(
        query,
        read_only,
        state.config.admin_allow_raw_sql,
        state.config.admin_allow_sql_write,
    ) {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: msg.into(),
        });
    }

    let result = sqlx::query(query).fetch_all(&state.pool).await;

    match result {
        Ok(rows) => {
            if rows.is_empty() {
                return HttpResponse::Ok().json(DbQueryResponse {
                    columns: vec![],
                    rows: vec![],
                });
            }
            let columns: Vec<String> = rows[0].columns().iter().map(|c| c.name().to_string()).collect();
            let json_rows: Vec<serde_json::Value> = rows
                .into_iter()
                .map(|row| {
                    let mut map = serde_json::Map::new();
                    for col in &columns {
                        let value: serde_json::Value = row.try_get(col.as_str()).unwrap_or(serde_json::Value::Null);
                        map.insert(col.clone(), value);
                    }
                    serde_json::Value::Object(map)
                })
                .collect();
            HttpResponse::Ok().json(DbQueryResponse {
                columns,
                rows: json_rows,
            })
        }
        Err(e) => {
            error!("DB query error: {}", e);
            HttpResponse::BadRequest().json(ErrorResponse {
                error: format!("Query error: {}", e),
            })
        }
    }
}

async fn user_db_query(
    state: web::Data<AppState>,
    req: HttpRequest,
    payload: web::Json<DbQueryRequest>,
) -> impl Responder {
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            });
        }
    };
    let _user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            });
        }
    };

    let query = payload.query.trim();
    if let Err(msg) = admin_sql::validate_admin_query(
        query,
        true,
        state.config.admin_allow_raw_sql,
        false,
    ) {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: msg.into(),
        });
    }

    match agent_integration::proxy_user_sql_to_agent(&state, &req, query).await {
        Err(r) => return r,
        Ok(Some(resp)) => return HttpResponse::Ok().json(resp),
        Ok(None) => {}
    }

    let result = sqlx::query(query).fetch_all(&state.pool).await;

    match result {
        Ok(rows) => {
            if rows.is_empty() {
                return HttpResponse::Ok().json(DbQueryResponse {
                    columns: vec![],
                    rows: vec![],
                });
            }
            let columns: Vec<String> = rows[0].columns().iter().map(|c| c.name().to_string()).collect();
            let json_rows: Vec<serde_json::Value> = rows
                .into_iter()
                .map(|row| {
                    let mut map = serde_json::Map::new();
                    for col in &columns {
                        let value: serde_json::Value =
                            row.try_get(col.as_str()).unwrap_or(serde_json::Value::Null);
                        map.insert(col.clone(), value);
                    }
                    serde_json::Value::Object(map)
                })
                .collect();
            HttpResponse::Ok().json(DbQueryResponse {
                columns,
                rows: json_rows,
            })
        }
        Err(e) => {
            error!("User DB query error: {}", e);
            HttpResponse::BadRequest().json(ErrorResponse {
                error: format!("Query error: {}", e),
            })
        }
    }
}

async fn admin_logs(
    state: web::Data<AppState>,
    req: HttpRequest,
    query: web::Query<LogsQuery>,
) -> impl Responder {
    debug_print!("Admin logs endpoint called");
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        }),
    };
    let user_id = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Invalid token".into(),
        }),
    };
    if !is_admin(&state.pool, user_id).await {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Access denied".into(),
        });
    }

    let limit = query.limit.unwrap_or(100) as i64;
    let logs = sqlx::query_as::<_, (Uuid, String, String, Option<String>, Option<String>, Option<i32>, chrono::DateTime<chrono::Utc>)>(
        "SELECT id, level, message, module, file, line, created_at FROM server_logs ORDER BY created_at DESC LIMIT $1"
    )
    .bind(limit)
    .fetch_all(&state.pool)
    .await;

    match logs {
        Ok(rows) => {
            let response: Vec<serde_json::Value> = rows
                .into_iter()
                .map(|(id, level, message, module, file, line, created_at)| {
                    serde_json::json!({
                        "id": id.to_string(),
                        "level": level,
                        "message": message,
                        "module": module,
                        "file": file,
                        "line": line,
                        "createdAt": created_at,
                    })
                })
                .collect();
            HttpResponse::Ok().json(response)
        }
        Err(e) => {
            error!("Failed to fetch logs: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to fetch logs".into(),
            })
        }
    }
}

async fn health() -> impl Responder {
    let svc = service::PoService::from_env();
    HttpResponse::Ok().json(serde_json::json!({
        "status": "ok",
        "service": svc.name(),
        "po_service": svc.name(),
    }))
}

async fn auth_introspect(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "JWT_SECRET not set".into(),
            });
        }
    };
    let Some(user_id) = get_user_id_from_token(&req, &jwt_secret) else {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "invalid or missing session".into(),
        });
    };
    let plan = waypoint_cabinet::billing_plan(&state.pool, user_id).await;
    let limit = roza_cabinet::roza_token_limit(&plan);
    let used: i32 = sqlx::query_scalar(
        r#"SELECT COALESCE(tokens_used, 0) FROM roza_token_daily
           WHERE user_id = $1 AND usage_date = (timezone('utc', now()))::date"#,
    )
    .bind(user_id)
    .fetch_optional(&state.pool)
    .await
    .ok()
    .flatten()
    .unwrap_or(0);

    HttpResponse::Ok().json(serde_json::json!({
        "active": true,
        "user_id": user_id.to_string(),
        "plan": plan,
        "roza": {
            "tokens_used": used,
            "tokens_limit": limit,
            "external_api": roza_cabinet::external_api_allowed(&plan),
        }
    }))
}

async fn health_head() -> impl Responder {
    HttpResponse::Ok().finish()
}

async fn ready(state: web::Data<AppState>) -> impl Responder {
    match sqlx::query_scalar::<_, i32>("SELECT 1")
        .fetch_one(&state.pool)
        .await
    {
        Ok(_) => HttpResponse::Ok().json(serde_json::json!({"status": "ready"})),
        Err(e) => {
            log::error!("ready check failed: {}", e);
            HttpResponse::ServiceUnavailable().json(ErrorResponse {
                error: "database unavailable".into(),
            })
        }
    }
}

async fn count_http_requests_for_metrics(
    req: ServiceRequest,
    next: Next<impl MessageBody>,
) -> Result<ServiceResponse<impl MessageBody>, actix_web::Error> {
    if let Some(st) = req.app_data::<web::Data<AppState>>() {
        st.http_request_counter
            .fetch_add(1, Ordering::Relaxed);
    }
    next.call(req).await
}

fn detect_po_service_from_exe() {
    if std::env::var("PO_SERVICE").is_ok() {
        return;
    }
    let Ok(exe) = std::env::current_exe() else {
        return;
    };
    let Some(stem) = exe.file_stem().and_then(|s| s.to_str()) else {
        return;
    };
    let svc = if stem.contains("auth-api") {
        "auth"
    } else if stem.contains("lynx-api") {
        "lynx"
    } else {
        "waypoint"
    };
    std::env::set_var("PO_SERVICE", svc);
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    detect_po_service_from_exe();
    let po_service = service::PoService::from_env();
    println!(">>> {} starting (PO_SERVICE={})...", po_service.name(), po_service.name());
    dotenv().ok();
    logging::init();
    println!(">>> Logger initialized");

    let runtime_config = Arc::new(config::RuntimeConfig::from_env());
    runtime_config.validate_secrets();

    let database_url = match env::var("DATABASE_URL") {
        Ok(url) if !url.trim().is_empty() => url,
        _ => {
            if !runtime_config.production {
                let fallback = "postgres://nexus:nexus@127.0.0.1:5432/nexus".to_string();
                info!("DATABASE_URL missing: using dev fallback {}", fallback);
                fallback
            } else {
                error!("DATABASE_URL not set");
                std::process::exit(1);
            }
        }
    };
    println!(">>> Database URL loaded");

    let pool = match PgPoolOptions::new()
        .max_connections(runtime_config.db_max_connections)
        .connect(&database_url)
        .await
    {
        Ok(p) => {
            info!("Connected to database");
            println!(">>> Database connection successful");
            p
        }
        Err(e) => {
            error!("Failed to connect to database: {}", e);
            println!(">>> Database connection FAILED: {}", e);
            std::process::exit(1);
        }
    };

    let run_migrations = env::var("RUN_MIGRATIONS")
        .ok()
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true") || v.eq_ignore_ascii_case("yes"))
        .unwrap_or(matches!(po_service, service::PoService::Auth));

    if run_migrations {
        if let Err(e) = sqlx::migrate!("./migrations").run(&pool).await {
            error!("Database migrations failed: {}", e);
            std::process::exit(1);
        }
        info!("Database migrations applied");
    } else {
        info!("RUN_MIGRATIONS=0 — skipping migrations ({})", po_service.name());
    }

    bootstrap::promote_first_nexus_if_configured(&pool).await;

    let pool_vk = pool.clone();
    tokio::spawn(async move {
        vk_notify::run_worker(pool_vk).await;
    });

    let pool_keys = pool.clone();
    tokio::spawn(async move {
        key_pool::ensure_admin_key_pool(&pool_keys).await;
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(300));
        loop {
            interval.tick().await;
            key_pool::ensure_admin_key_pool(&pool_keys).await;
        }
    });

    info!(
        "http_workers={} db_max_connections={}",
        runtime_config.http_workers,
        runtime_config.db_max_connections
    );

    let metrics_store = Arc::new(Mutex::new(MetricsStore::new(60)));
    let store_clone = metrics_store.clone();
    let http_request_counter = Arc::new(AtomicUsize::new(0));
    let http_request_counter_metrics = http_request_counter.clone();

    tokio::spawn(async move {
        let mut interval = time::interval(time::Duration::from_secs(5));
        loop {
            interval.tick().await;
            let http_hits = http_request_counter_metrics.swap(0, Ordering::Relaxed);
            let snap = tokio::task::spawn_blocking(|| {
                let mut sys = System::new_all();
                let mut disks = Disks::new_with_refreshed_list();
                let mut networks = Networks::new_with_refreshed_list();
                sys.refresh_all();
                disks.refresh(true);
                networks.refresh(true);
                (sys, disks, networks)
            })
            .await;
            match snap {
                Ok((sys, disks, networks)) => {
                    let mut store = store_clone.lock().await;
                    store.add_point(&sys, &disks, &networks, http_hits);
                }
                Err(e) => {
                    log::error!("metrics spawn_blocking join: {}", e);
                }
            }
        }
    });

    let connected_metrics_store = Arc::new(Mutex::new(ConnectedMetricsStore::new(60)));

    let prometheus = match observability::PrometheusHandles::new() {
        Ok(h) => Some(std::sync::Arc::new(h)),
        Err(e) => {
            error!("Prometheus metrics init failed: {}", e);
            None
        }
    };

    let http_client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(5))
        .build()
        .unwrap_or_else(|_| reqwest::Client::new());

    let redis = match std::env::var("REDIS_URL") {
        Ok(url) if !url.trim().is_empty() => match redis::Client::open(url.as_str()) {
            Ok(client) => match redis::aio::ConnectionManager::new(client).await {
                Ok(m) => {
                    info!("Redis connection manager ready");
                    Some(m)
                }
                Err(e) => {
                    log::warn!("REDIS_URL set but connection failed: {}", e);
                    None
                }
            },
            Err(e) => {
                log::warn!("Invalid REDIS_URL: {}", e);
                None
            }
        },
        _ => None,
    };

    let app_state = web::Data::new(AppState {
        pool: pool.clone(),
        metrics: metrics_store,
        connected_metrics: connected_metrics_store,
        http_request_counter,
        config: runtime_config.clone(),
        scene_collab: Arc::new(scene_ws::SceneCollab::new()),
        studio_collab: Arc::new(studio_ws::StudioCollab::new()),
        prometheus,
        http_client,
        redis,
    });

    let bind_addr = env::var("BIND_ADDRESS")
        .ok()
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| po_service.default_bind_address().to_string());
    println!(">>> Binding {} to {}", po_service.name(), bind_addr);

    let governor_conf = GovernorConfigBuilder::default()
        .per_second(60)
        .burst_size(120)
        .key_extractor(rate_limit_key::ForwardedIpKeyExtractor)
        .finish()
        .expect("governor config");

    let pool_data = web::Data::new(pool.clone());
    let rt_limit = runtime_config.rate_limit_enabled;
    let rc_cors = runtime_config.clone();
    let server = HttpServer::new(move || {
        let cors = config::build_cors(rc_cors.as_ref());

        po_configure_routes!(
            App::new()
                .app_data(app_state.clone())
                .app_data(pool_data.clone())
                .wrap(from_fn(count_http_requests_for_metrics))
                .wrap(Condition::new(rt_limit, Governor::new(&governor_conf)))
                .wrap(actix_web::middleware::Logger::default())
                .wrap(cors),
            po_service
        )
    })
    .workers(runtime_config.http_workers)
    .bind(&bind_addr)?;

    println!(">>> Server bound, starting to run");
    info!("Server listening on http://{}", bind_addr);

    server.run().await?;
    println!(">>> Server stopped");
    Ok(())
}

#[cfg(test)]
mod http_smoke_tests {
    use super::*;
    use actix_web::{test, web, App};

    #[actix_web::test]
    async fn health_endpoint_ok() {
        let app = test::init_service(App::new().route("/health", web::get().to(health))).await;
        let req = test::TestRequest::get().uri("/health").to_request();
        let resp = test::call_service(&app, req).await;
        assert!(resp.status().is_success());
    }
}