use anyhow::{Context, Result};
use axum::{
    body::Body,
    extract::{Multipart, Path as AxumPath, State},
    http::{header, HeaderValue, StatusCode},
    response::IntoResponse,
    Json,
};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{
    fs,
    path::{Path as StdPath, PathBuf},
};
use uuid::Uuid;

#[derive(Clone)]
pub struct ArcadeState {
    pub data_dir: PathBuf,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct ArcadeCartMeta {
    pub id: String,
    pub title: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub tier: String,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(rename = "cartUrl")]
    pub cart_url: String,
    #[serde(rename = "thumbnailUrl", default)]
    pub thumbnail_url: Option<String>,
    #[serde(rename = "projectTemplate", default)]
    pub project_template: Option<String>,
    #[serde(rename = "updatedAt")]
    pub updated_at: String,
}

#[derive(Serialize, Deserialize, Clone)]
struct ArcadeCatalogFile {
    #[serde(rename = "apiVersion", default)]
    api_version: u32,
    #[serde(rename = "updatedAt", default)]
    updated_at: Option<String>,
    #[serde(default)]
    items: Vec<ArcadeCartMeta>,
}

#[derive(Serialize)]
pub struct ArcadeCatalogResponse {
    #[serde(rename = "apiVersion")]
    pub api_version: u32,
    #[serde(rename = "updatedAt")]
    pub updated_at: String,
    pub items: Vec<ArcadeCartMeta>,
}

#[derive(Serialize)]
pub struct UploadCartResponse {
    pub ok: bool,
    pub id: String,
    pub title: String,
    #[serde(rename = "cartUrl")]
    pub cart_url: String,
    pub message: String,
}

fn carts_dir(data_dir: &StdPath) -> PathBuf {
    data_dir.join("arcade_carts")
}

fn catalog_path(data_dir: &StdPath) -> PathBuf {
    data_dir.join("arcade_catalog.json")
}

fn load_catalog(data_dir: &StdPath) -> Result<ArcadeCatalogFile> {
    let path = catalog_path(data_dir);
    if !path.exists() {
        return Ok(ArcadeCatalogFile {
            api_version: 1,
            updated_at: None,
            items: vec![],
        });
    }
    let raw = fs::read_to_string(&path).with_context(|| format!("read {}", path.display()))?;
    let mut cat: ArcadeCatalogFile = serde_json::from_str(&raw)?;
    if cat.api_version == 0 {
        cat.api_version = 1;
    }
    Ok(cat)
}

fn save_catalog(data_dir: &StdPath, cat: &ArcadeCatalogFile) -> Result<()> {
    let path = catalog_path(data_dir);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let mut out = cat.clone();
    out.updated_at = Some(Utc::now().to_rfc3339());
    fs::write(&path, serde_json::to_string_pretty(&out)?)?;
    Ok(())
}

pub async fn get_catalog(State(st): State<ArcadeState>) -> Result<Json<ArcadeCatalogResponse>, StatusCode> {
    let cat = load_catalog(&st.data_dir).map_err(|e| {
        tracing::error!("arcade catalog: {e}");
        StatusCode::INTERNAL_SERVER_ERROR
    })?;
    Ok(Json(ArcadeCatalogResponse {
        api_version: cat.api_version.max(1),
        updated_at: cat
            .updated_at
            .unwrap_or_else(|| Utc::now().to_rfc3339()),
        items: cat.items,
    }))
}

pub async fn upload_cart(
    State(st): State<ArcadeState>,
    _user: super::auth::UserId,
    mut multipart: Multipart,
) -> Result<Json<UploadCartResponse>, StatusCode> {
    let mut title = String::from("Lynx Cart");
    let mut description = String::new();
    let mut tier = String::from("free_to_play");
    let mut tags: Vec<String> = vec![];
    let mut cart_id: Option<String> = None;
    let mut bytes: Option<Vec<u8>> = None;

    while let Some(field) = multipart.next_field().await.map_err(|_| StatusCode::BAD_REQUEST)? {
        let name = field.name().unwrap_or("").to_string();
        match name.as_str() {
            "cart" | "file" => {
                bytes = Some(field.bytes().await.map_err(|_| StatusCode::BAD_REQUEST)?.to_vec());
            }
            "title" => {
                title = field.text().await.unwrap_or_default();
            }
            "description" => {
                description = field.text().await.unwrap_or_default();
            }
            "tier" => {
                tier = field.text().await.unwrap_or_else(|_| "free_to_play".into());
            }
            "tags" => {
                let t = field.text().await.unwrap_or_default();
                tags = t
                    .split(',')
                    .map(|s| s.trim().to_string())
                    .filter(|s| !s.is_empty())
                    .collect();
            }
            "cartId" | "id" => {
                cart_id = Some(field.text().await.unwrap_or_default());
            }
            _ => {}
        }
    }

    let data = bytes.ok_or(StatusCode::BAD_REQUEST)?;
    if data.len() < 8 {
        return Err(StatusCode::BAD_REQUEST);
    }

    let id = cart_id
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| Uuid::new_v4().to_string());
    let dir = carts_dir(&st.data_dir);
    fs::create_dir_all(&dir).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let file_path = dir.join(format!("{id}.lynxcart"));
    fs::write(&file_path, &data).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let cart_url = format!("/v1/arcade/carts/{id}/download");
    let meta = ArcadeCartMeta {
        id: id.clone(),
        title: title.clone(),
        description,
        tier,
        tags,
        cart_url: cart_url.clone(),
        thumbnail_url: None,
        project_template: None,
        updated_at: Utc::now().to_rfc3339(),
    };

    let mut cat = load_catalog(&st.data_dir).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    cat.items.retain(|i| i.id != id);
    cat.items.push(meta);
    save_catalog(&st.data_dir, &cat).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(UploadCartResponse {
        ok: true,
        id,
        title,
        cart_url,
        message: "Cart опубликован в Arcade".into(),
    }))
}

pub async fn download_cart(
    State(st): State<ArcadeState>,
    AxumPath(id): AxumPath<String>,
) -> Result<impl IntoResponse, StatusCode> {
    let path = carts_dir(&st.data_dir).join(format!("{id}.lynxcart"));
    let bytes = fs::read(&path).map_err(|_| StatusCode::NOT_FOUND)?;
    let mut headers = axum::http::HeaderMap::new();
    headers.insert(
        header::CONTENT_TYPE,
        HeaderValue::from_static("application/octet-stream"),
    );
    headers.insert(
        header::CONTENT_DISPOSITION,
        HeaderValue::from_str(&format!("attachment; filename=\"{id}.lynxcart\""))
            .unwrap_or(HeaderValue::from_static("attachment")),
    );
    Ok((headers, Body::from(bytes)))
}

pub async fn get_cart_meta(
    State(st): State<ArcadeState>,
    AxumPath(id): AxumPath<String>,
) -> Result<Json<Value>, StatusCode> {
    let cat = load_catalog(&st.data_dir).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let item = cat.items.iter().find(|i| i.id == id);
    match item {
        Some(m) => Ok(Json(json!(m))),
        None => Err(StatusCode::NOT_FOUND),
    }
}
