//! Cloud Arcade: publish and play `.lynxcart` games (L18).

use actix_multipart::Multipart;
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use chrono::Utc;
use futures_util::StreamExt;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::fs;
use std::path::PathBuf;
use uuid::Uuid;

use crate::{get_user_id_from_token, AppState, ErrorResponse};

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

#[derive(Serialize, Deserialize, Clone, Default)]
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

fn arcade_root() -> PathBuf {
    std::env::var("LYNX_ARCADE_DATA_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("./uploads/arcade"))
}

fn carts_dir() -> PathBuf {
    arcade_root().join("carts")
}

fn catalog_path() -> PathBuf {
    arcade_root().join("arcade_catalog.json")
}

fn load_catalog() -> Result<ArcadeCatalogFile, std::io::Error> {
    let path = catalog_path();
    if !path.exists() {
        return Ok(ArcadeCatalogFile {
            api_version: 1,
            updated_at: None,
            items: vec![],
        });
    }
    let raw = fs::read_to_string(&path)?;
    let mut cat: ArcadeCatalogFile = serde_json::from_str(&raw).unwrap_or_default();
    if cat.api_version == 0 {
        cat.api_version = 1;
    }
    Ok(cat)
}

fn save_catalog(cat: &ArcadeCatalogFile) -> Result<(), std::io::Error> {
    let root = arcade_root();
    fs::create_dir_all(&root)?;
    let mut out = cat.clone();
    out.updated_at = Some(Utc::now().to_rfc3339());
    fs::write(catalog_path(), serde_json::to_string_pretty(&out).unwrap_or_default())
}

fn hub_admin_ok(req: &HttpRequest) -> bool {
    let expected = std::env::var("LYNX_HUB_ADMIN_TOKEN").unwrap_or_default();
    if expected.is_empty() {
        return false;
    }
    let got = req
        .headers()
        .get("X-Lynx-Hub-Admin-Token")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    got == expected
}

pub async fn get_catalog() -> impl Responder {
    match load_catalog() {
        Ok(cat) => HttpResponse::Ok().json(ArcadeCatalogResponse {
            api_version: cat.api_version.max(1),
            updated_at: cat
                .updated_at
                .unwrap_or_else(|| Utc::now().to_rfc3339()),
            items: cat.items,
        }),
        Err(e) => {
            log::error!("arcade catalog: {e}");
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Failed to load arcade catalog".into(),
            })
        }
    }
}

pub async fn upload_cart(
    state: web::Data<AppState>,
    req: HttpRequest,
    mut payload: Multipart,
) -> impl Responder {
    let allowed = if hub_admin_ok(&req) {
        true
    } else if let Ok(jwt) = std::env::var("JWT_SECRET") {
        if let Some(uid) = get_user_id_from_token(&req, &jwt) {
            crate::authz::is_lynx_ops(&state.pool, uid).await
        } else {
            false
        }
    } else {
        false
    };
    if !allowed {
        return HttpResponse::Unauthorized().json(ErrorResponse {
            error: "Authorization required".into(),
        });
    }

    let mut title = String::from("Lynx Cart");
    let mut description = String::new();
    let mut tier = String::from("free_to_play");
    let mut tags: Vec<String> = vec![];
    let mut cart_id: Option<String> = None;
    let mut bytes: Option<Vec<u8>> = None;

    while let Some(Ok(mut field)) = payload.next().await {
        let name = field
            .content_disposition()
            .and_then(|cd| cd.get_name().map(|s| s.to_string()))
            .unwrap_or_default();
        match name.as_str() {
            "cart" | "file" => {
                let mut buf = Vec::new();
                while let Some(Ok(chunk)) = field.next().await {
                    buf.extend_from_slice(&chunk);
                }
                bytes = Some(buf);
            }
            "title" => {
                let mut buf = Vec::new();
                while let Some(Ok(chunk)) = field.next().await {
                    buf.extend_from_slice(&chunk);
                }
                title = String::from_utf8_lossy(&buf).to_string();
            }
            "description" => {
                let mut buf = Vec::new();
                while let Some(Ok(chunk)) = field.next().await {
                    buf.extend_from_slice(&chunk);
                }
                description = String::from_utf8_lossy(&buf).to_string();
            }
            "tier" => {
                let mut buf = Vec::new();
                while let Some(Ok(chunk)) = field.next().await {
                    buf.extend_from_slice(&chunk);
                }
                tier = String::from_utf8_lossy(&buf).to_string();
            }
            "tags" => {
                let mut buf = Vec::new();
                while let Some(Ok(chunk)) = field.next().await {
                    buf.extend_from_slice(&chunk);
                }
                let t = String::from_utf8_lossy(&buf);
                tags = t
                    .split(',')
                    .map(|s| s.trim().to_string())
                    .filter(|s| !s.is_empty())
                    .collect();
            }
            "cartId" | "id" => {
                let mut buf = Vec::new();
                while let Some(Ok(chunk)) = field.next().await {
                    buf.extend_from_slice(&chunk);
                }
                cart_id = Some(String::from_utf8_lossy(&buf).to_string());
            }
            _ => {}
        }
    }

    let data = match bytes {
        Some(b) if b.len() >= 8 => b,
        _ => {
            return HttpResponse::BadRequest().json(ErrorResponse {
                error: "cart file required".into(),
            })
        }
    };

    let id = cart_id
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| Uuid::new_v4().to_string());

    let dir = carts_dir();
    if let Err(e) = fs::create_dir_all(&dir) {
        log::error!("arcade mkdir: {e}");
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Storage error".into(),
        });
    }
    let file_path = dir.join(format!("{id}.lynxcart"));
    if let Err(e) = fs::write(&file_path, &data) {
        log::error!("arcade write: {e}");
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Write failed".into(),
        });
    }

    let cart_url = format!("/v1/arcade/carts/{id}/download");
    let meta = ArcadeCartMeta {
        id: id.clone(),
        title: title.clone(),
        description,
        tier,
        tags: if tags.is_empty() {
            vec!["arcade".into()]
        } else {
            tags
        },
        cart_url: cart_url.clone(),
        thumbnail_url: None,
        project_template: None,
        updated_at: Utc::now().to_rfc3339(),
    };

    let mut cat = match load_catalog() {
        Ok(c) => c,
        Err(e) => {
            log::error!("arcade catalog load: {e}");
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Catalog error".into(),
            });
        }
    };
    cat.items.retain(|i| i.id != id);
    cat.items.push(meta);
    if let Err(e) = save_catalog(&cat) {
        log::error!("arcade catalog save: {e}");
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Catalog save failed".into(),
        });
    }

    HttpResponse::Ok().json(UploadCartResponse {
        ok: true,
        id,
        title,
        cart_url,
        message: "Cart опубликован в Arcade".into(),
    })
}

pub async fn download_cart(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<String>,
) -> impl Responder {
    let id = path.into_inner();
    if id.contains("..") || id.contains('/') {
        return HttpResponse::BadRequest().finish();
    }
    let user_id = std::env::var("JWT_SECRET")
        .ok()
        .and_then(|jwt| get_user_id_from_token(&req, &jwt));
    crate::nexus_cloud::record_asset_download(&state.pool, "arcade_cart", &id, user_id).await;
    let file_path = carts_dir().join(format!("{id}.lynxcart"));
    match fs::read(&file_path) {
        Ok(bytes) => HttpResponse::Ok()
            .content_type("application/octet-stream")
            .insert_header((
                actix_web::http::header::CONTENT_DISPOSITION,
                format!("attachment; filename=\"{id}.lynxcart\""),
            ))
            .body(bytes),
        Err(_) => HttpResponse::NotFound().json(ErrorResponse {
            error: "Cart not found".into(),
        }),
    }
}

pub async fn get_cart_meta(path: web::Path<String>) -> impl Responder {
    let id = path.into_inner();
    let cat = match load_catalog() {
        Ok(c) => c,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Catalog error".into(),
            })
        }
    };
    match cat.items.iter().find(|i| i.id == id) {
        Some(m) => HttpResponse::Ok().json(json!(m)),
        None => HttpResponse::NotFound().json(ErrorResponse {
            error: "Not found".into(),
        }),
    }
}

pub fn ensure_dirs() {
    let _ = fs::create_dir_all(carts_dir());
}
