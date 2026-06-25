use actix_web::{web, HttpRequest, HttpResponse, Responder};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::env;

use crate::{authz, AppState, ErrorResponse};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EngineArtifact {
    pub url: String,
    #[serde(default)]
    pub sha256: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EngineRelease {
    pub version: String,
    #[serde(default)]
    pub notes: Option<String>,
    #[serde(default)]
    pub channel: Option<String>,
    #[serde(default)]
    pub artifacts: std::collections::HashMap<String, EngineArtifact>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EngineManifest {
    #[serde(default)]
    pub releases: Vec<EngineRelease>,
    #[serde(default)]
    pub recommended_version: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct EnginePolicyResponse {
    pub manifest_url: Option<String>,
    pub recommended_version: Option<String>,
    pub updated_at: Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Debug, Deserialize)]
pub struct EnginePolicyUpdate {
    #[serde(default)]
    pub manifest_url: Option<String>,
    #[serde(default)]
    pub recommended_version: Option<String>,
}

async fn load_policy(pool: &PgPool) -> (Option<String>, Option<String>, Option<chrono::DateTime<chrono::Utc>>) {
    let row: Option<(Option<String>, Option<String>, chrono::DateTime<chrono::Utc>)> = sqlx::query_as(
        "SELECT manifest_url, recommended_version, updated_at FROM nexus_engine_policy WHERE id = 1",
    )
    .fetch_optional(pool)
    .await
    .unwrap_or(None);
    match row {
        Some((u, v, t)) => (u, v, Some(t)),
        None => (None, None, None),
    }
}

fn strip_utf8_bom(text: &str) -> &str {
    text.strip_prefix('\u{feff}').unwrap_or(text)
}

fn parse_manifest_json(text: &str) -> Result<EngineManifest, String> {
    let text = strip_utf8_bom(text.trim());
    serde_json::from_str::<EngineManifest>(text)
        .map_err(|e| format!("manifest JSON: {e}. Ожидается {{ \"releases\": [...] }}"))
}

fn manifest_from_env_json() -> Option<EngineManifest> {
    let raw = env::var("LYNX_ENGINE_MANIFEST_JSON")
        .ok()
        .filter(|s| !s.trim().is_empty())
        .or_else(|| {
            env::var("NEXUS_ENGINE_MANIFEST_JSON")
                .ok()
                .filter(|s| !s.trim().is_empty())
        })?;
    parse_manifest_json(&raw).ok()
}

pub async fn fetch_manifest_from_url(url: &str) -> Result<EngineManifest, String> {
    fetch_remote_manifest(url).await
}

async fn load_manifest_text(url: &str) -> Result<String, String> {
    let trimmed = url.trim();
    if let Some(path) = trimmed.strip_prefix("file://") {
        return tokio::fs::read_to_string(path)
            .await
            .map_err(|e| format!("read manifest file {path}: {e}"));
    }
    if trimmed.starts_with('/') {
        return tokio::fs::read_to_string(trimmed)
            .await
            .map_err(|e| format!("read manifest file {trimmed}: {e}"));
    }

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(20))
        .build()
        .map_err(|e| e.to_string())?;
    client
        .get(trimmed)
        .send()
        .await
        .map_err(|e| e.to_string())?
        .error_for_status()
        .map_err(|e| e.to_string())?
        .text()
        .await
        .map_err(|e| e.to_string())
}

async fn fetch_remote_manifest(url: &str) -> Result<EngineManifest, String> {
    let text = load_manifest_text(url).await?;
    let mut m = parse_manifest_json(&text)?;
    m.source = Some(
        if url.trim().starts_with("file://") || url.trim().starts_with('/') {
            "file"
        } else {
            "remote"
        }
        .into(),
    );
    Ok(m)
}

pub async fn build_manifest(pool: &PgPool) -> EngineManifest {
    let (policy_url, recommended, _) = load_policy(pool).await;
    let mut result = if let Some(ref url) = policy_url {
        if !url.trim().is_empty() {
            match fetch_remote_manifest(url.trim()).await {
                Ok(m) => m,
                Err(e) => {
                    log::warn!("engine manifest fetch failed: {e}");
                    manifest_from_env_json().unwrap_or_else(|| EngineManifest {
                        releases: vec![],
                        recommended_version: None,
                        source: Some("error".into()),
                    })
                }
            }
        } else {
            manifest_from_env_json().unwrap_or_else(|| EngineManifest {
                releases: vec![],
                recommended_version: None,
                source: Some("empty_policy_url".into()),
            })
        }
    } else {
        manifest_from_env_json().unwrap_or_else(|| EngineManifest {
            releases: vec![],
            recommended_version: None,
            source: Some("default".into()),
        })
    };

    result.recommended_version = recommended.or(result.recommended_version);
    if result.source.is_none() {
        result.source = if policy_url.as_ref().map(|s| !s.trim().is_empty()).unwrap_or(false) {
            Some("remote".into())
        } else if manifest_from_env_json().is_some() {
            Some("env".into())
        } else {
            Some("none".into())
        };
    }
    result
}

pub async fn public_manifest(state: web::Data<AppState>) -> impl Responder {
    let m = build_manifest(&state.pool).await;
    HttpResponse::Ok().json(m)
}

pub async fn admin_get_policy(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    if let Err(resp) = authz::require_lynx_ops(&state.pool, &req).await {
        return resp;
    }
    let (manifest_url, recommended_version, updated_at) = load_policy(&state.pool).await;
    HttpResponse::Ok().json(EnginePolicyResponse {
        manifest_url,
        recommended_version,
        updated_at,
    })
}

pub async fn admin_put_policy(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<EnginePolicyUpdate>,
) -> impl Responder {
    if let Err(resp) = authz::require_lynx_ops(&state.pool, &req).await {
        return resp;
    }
    let body = body.into_inner();
    let (mut u, mut v, _) = load_policy(&state.pool).await;
    if let Some(x) = body.manifest_url {
        u = if x.trim().is_empty() { None } else { Some(x.trim().to_string()) };
    }
    if let Some(x) = body.recommended_version {
        v = if x.trim().is_empty() { None } else { Some(x.trim().to_string()) };
    }
    if let Err(e) = sqlx::query(
        "UPDATE nexus_engine_policy SET manifest_url = $1, recommended_version = $2, updated_at = now() WHERE id = 1",
    )
    .bind(&u)
    .bind(&v)
    .execute(&state.pool)
    .await
    {
        log::error!("engine policy update: {}", e);
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "database error".into(),
        });
    }
    let (manifest_url, recommended_version, updated_at) = load_policy(&state.pool).await;
    HttpResponse::Ok().json(EnginePolicyResponse {
        manifest_url,
        recommended_version,
        updated_at,
    })
}

pub async fn load_manifest_for_admin(pool: &PgPool) -> EngineManifest {
    build_manifest(pool).await
}
