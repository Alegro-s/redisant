
use actix_cors::Cors;
use actix_web::http::Method;
use std::env;

fn default_http_workers() -> usize {
    std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
        .max(1)
}

#[derive(Clone, Debug)]
pub struct RuntimeConfig {
    pub production: bool,
    pub bind_address: String,
    pub http_workers: usize,
    pub db_max_connections: u32,
    pub cors_origins: Vec<String>,
    pub admin_allow_raw_sql: bool,
    pub admin_allow_sql_write: bool,
    pub rate_limit_enabled: bool,
    pub admin_open_registration: bool,
    pub session_jwt_ttl_hours: i64,
    pub session_cookie_secure: bool,
}

impl RuntimeConfig {
    pub fn from_env() -> Self {
        let production = matches!(
            env::var("WAYPOINT_ENV")
                .or_else(|_| env::var("NEXUS_ENV"))
                .unwrap_or_default()
                .to_lowercase()
                .as_str(),
            "production" | "prod"
        );

        let bind_address = env::var("BIND_ADDRESS").unwrap_or_else(|_| {
            if production {
                "0.0.0.0:8080".into()
            } else {
                "127.0.0.1:8080".into()
            }
        });

        let http_workers = env::var("HTTP_WORKERS")
            .ok()
            .and_then(|s| s.parse::<usize>().ok())
            .filter(|&n| n > 0)
            .unwrap_or_else(default_http_workers);

        let db_max_connections = env::var("DATABASE_MAX_CONNECTIONS")
            .ok()
            .and_then(|s| s.parse::<u32>().ok())
            .filter(|&n| n > 0)
            .unwrap_or_else(|| {
                ((http_workers as u32).saturating_mul(4))
                    .clamp(5, 128)
            });

        let cors_origins: Vec<String> = env::var("CORS_ALLOWED_ORIGINS")
            .unwrap_or_default()
            .split(',')
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty())
            .collect();

        let admin_allow_raw_sql = match env::var("ADMIN_ALLOW_RAW_SQL") {
            Ok(v) => v == "1" || v.eq_ignore_ascii_case("true"),
            Err(_) => !production,
        };

        let admin_allow_sql_write = match env::var("ADMIN_ALLOW_SQL_WRITE") {
            Ok(v) => v == "1" || v.eq_ignore_ascii_case("true"),
            Err(_) => false,
        };

        let rate_limit_enabled = match env::var("RATE_LIMIT_ENABLED") {
            Ok(v) => v != "0" && !v.eq_ignore_ascii_case("false"),
            Err(_) => true,
        };

        let admin_open_registration = match env::var("ADMIN_OPEN_REGISTRATION") {
            Ok(v) => v == "1" || v.eq_ignore_ascii_case("true"),
            Err(_) => false,
        };

        let session_jwt_ttl_hours = env::var("SESSION_JWT_TTL_HOURS")
            .ok()
            .and_then(|s| s.parse::<i64>().ok())
            .filter(|&h| h > 0 && h <= 168)
            .unwrap_or(12);

        let session_cookie_secure = match env::var("SESSION_COOKIE_SECURE") {
            Ok(v) => v == "1" || v.eq_ignore_ascii_case("true"),
            Err(_) => production,
        };

        Self {
            production,
            bind_address,
            http_workers,
            db_max_connections,
            cors_origins,
            admin_allow_raw_sql,
            admin_allow_sql_write,
            rate_limit_enabled,
            admin_open_registration,
            session_jwt_ttl_hours,
            session_cookie_secure,
        }
    }

    pub fn validate_secrets(&self) {
        if !self.production {
            return;
        }
        let jwt = env::var("JWT_SECRET").unwrap_or_default();
        if jwt.len() < 32 {
            panic!(
                "NEXUS_ENV=production: JWT_SECRET must be at least 32 characters (got {})",
                jwt.len()
            );
        }
    }
}

pub fn build_cors(cfg: &RuntimeConfig) -> Cors {
    let methods = vec![
        Method::GET,
        Method::POST,
        Method::PUT,
        Method::PATCH,
        Method::DELETE,
        Method::OPTIONS,
    ];

    if !cfg.production && cfg.cors_origins.is_empty() {
        return Cors::default()
            .allowed_methods(methods)
            .allowed_origin_fn(|origin, _req_head| {
                let o = origin.as_bytes();
                o.starts_with(b"http://localhost:")
                    || o.starts_with(b"http://127.0.0.1:")
                    || o.starts_with(b"http://[::1]:")
            })
            .allow_any_header()
            .supports_credentials()
            .max_age(3600);
    }

    let mut c = Cors::default()
        .allowed_methods(methods)
        .allow_any_header()
        .supports_credentials()
        .max_age(3600);
    for origin in &cfg.cors_origins {
        c = c.allowed_origin(origin.as_str());
    }
    if cfg.production && cfg.cors_origins.is_empty() {
        log::warn!(
            "CORS_ALLOWED_ORIGINS is empty: cross-origin browser requests are not whitelisted (OK for mobile / same-origin)."
        );
    }
    c
}
