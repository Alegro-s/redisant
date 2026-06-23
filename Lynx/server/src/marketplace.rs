use anyhow::{Context, Result};
use axum::{
    body::Body,
    extract::{Path as AxumPath, State},
    http::{header, HeaderValue, StatusCode},
    response::IntoResponse,
    Json,
};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::{
    collections::{HashMap, HashSet},
    path::{Path as StdPath, PathBuf},
    sync::Arc,
};
use tokio::sync::RwLock;

#[derive(Clone)]
pub struct MarketplaceState {
    pub data_dir: PathBuf,
    pub licenses: Arc<RwLock<HashMap<String, HashSet<String>>>>,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct CatalogFile {
    #[serde(rename = "apiVersion", default)]
    pub api_version: u32,
    #[serde(rename = "updatedAt")]
    pub updated_at: Option<String>,
    #[serde(default)]
    pub items: Vec<Value>,
}

#[derive(Serialize)]
pub struct CatalogResponse {
    #[serde(rename = "apiVersion")]
    pub api_version: u32,
    #[serde(rename = "updatedAt")]
    pub updated_at: String,
    pub items: Vec<Value>,
    pub source: &'static str,
}

#[derive(Serialize)]
pub struct ClaimResponse {
    pub ok: bool,
    pub item_id: String,
    pub message: String,
    #[serde(rename = "downloadPath")]
    pub download_path: Option<String>,
}

pub fn load_catalog(data_dir: &StdPath) -> Result<CatalogFile> {
    let path = data_dir.join("marketplace_catalog.json");
    let raw = std::fs::read_to_string(&path)
        .with_context(|| format!("read {}", path.display()))?;
    let mut cat: CatalogFile = serde_json::from_str(&raw)?;
    if cat.api_version == 0 {
        cat.api_version = 1;
    }
    Ok(cat)
}

pub async fn get_catalog(
    State(st): State<MarketplaceState>,
) -> Result<Json<CatalogResponse>, StatusCode> {
    let cat = load_catalog(&st.data_dir).map_err(|e| {
        tracing::error!("catalog: {e}");
        StatusCode::INTERNAL_SERVER_ERROR
    })?;
    Ok(Json(CatalogResponse {
        api_version: cat.api_version,
        updated_at: cat
            .updated_at
            .unwrap_or_else(|| Utc::now().to_rfc3339()),
        items: cat.items,
        source: "lynx-cloud",
    }))
}

pub async fn claim_item(
    State(st): State<MarketplaceState>,
    user_id: super::auth::UserId,
    AxumPath(item_id): AxumPath<String>,
) -> Result<Json<ClaimResponse>, StatusCode> {
    let cat = load_catalog(&st.data_dir).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let item = cat
        .items
        .iter()
        .find(|i| i.get("id").and_then(|v| v.as_str()) == Some(item_id.as_str()));
    let Some(item) = item else {
        return Ok(Json(ClaimResponse {
            ok: false,
            item_id,
            message: "Пакет не найден".into(),
            download_path: None,
        }));
    };
    // Beta: all catalog items are free — see docs/BETA_FREE.md (no price gate).
    let id = item.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
    st.licenses
        .write()
        .await
        .entry(user_id.0)
        .or_default()
        .insert(id.clone());
    let download_path = if item.get("builtin").and_then(|v| v.as_bool()) == Some(true) {
        None
    } else {
        Some(format!("/v1/marketplace/items/{id}/download"))
    };
    Ok(Json(ClaimResponse {
        ok: true,
        item_id: id,
        message: "Лицензия выдана".into(),
        download_path,
    }))
}

pub async fn download_item(
    State(st): State<MarketplaceState>,
    user_id: super::auth::UserId,
    AxumPath(item_id): AxumPath<String>,
) -> Result<impl IntoResponse, StatusCode> {
    let allowed = st
        .licenses
        .read()
        .await
        .get(&user_id.0)
        .map(|s| s.contains(&item_id))
        .unwrap_or(false);
    let cat = load_catalog(&st.data_dir).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let item = cat.items.iter().find(|i| {
        i.get("id").and_then(|v| v.as_str()) == Some(item_id.as_str())
    });
    let free = item
        .and_then(|i| i.get("price").and_then(|v| v.as_f64()))
        .unwrap_or(0.0)
        == 0.0;
    if !allowed && !free {
        return Err(StatusCode::FORBIDDEN);
    }
    let zip_path = st.data_dir.join("packages").join(format!("{item_id}.zip"));
    if !zip_path.is_file() {
        return Err(StatusCode::NOT_FOUND);
    }
    let bytes = tokio::fs::read(&zip_path)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let disp = HeaderValue::from_str(&format!("attachment; filename=\"{item_id}.zip\""))
        .unwrap_or(HeaderValue::from_static("attachment"));
    Ok((
        [
            (header::CONTENT_TYPE, HeaderValue::from_static("application/zip")),
            (header::CONTENT_DISPOSITION, disp),
        ],
        Body::from(bytes),
    ))
}

pub async fn persist_licenses(st: &MarketplaceState) -> Result<()> {
    let map = st.licenses.read().await.clone();
    let path = st.data_dir.join("marketplace_licenses.json");
    let json = serde_json::to_string_pretty(&map)?;
    tokio::fs::write(path, json).await?;
    Ok(())
}

pub fn load_licenses(data_dir: &StdPath) -> HashMap<String, HashSet<String>> {
    let path = data_dir.join("marketplace_licenses.json");
    let Ok(raw) = std::fs::read_to_string(path) else {
        return HashMap::new();
    };
    serde_json::from_str(&raw).unwrap_or_default()
}
