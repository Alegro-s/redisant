//! Hub public content: news, engine cores, marketplace catalog (admin via token).

use actix_web::{web, HttpRequest, HttpResponse, Responder};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

use crate::ErrorResponse;

#[derive(Clone, Serialize, Deserialize, Default)]
pub struct HubNewsPost {
    pub slug: String,
    pub title: String,
    pub date: String,
    pub body: String,
}

#[derive(Clone, Serialize, Deserialize, Default)]
pub struct HubEngineCore {
    pub id: String,
    pub label: String,
    pub version: String,
    pub note: String,
}

#[derive(Clone, Serialize, Deserialize, Default)]
pub struct HubContent {
    pub news: Vec<HubNewsPost>,
    #[serde(rename = "engineCores")]
    pub engine_cores: Vec<HubEngineCore>,
}

fn hub_data_root() -> PathBuf {
    std::env::var("LYNX_HUB_DATA_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("./uploads/hub"))
}

fn hub_content_path() -> PathBuf {
    hub_data_root().join("hub_content.json")
}

fn marketplace_catalog_path() -> PathBuf {
    hub_data_root().join("marketplace_catalog.json")
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

pub fn load_hub_content_disk() -> HubContent {
    let path = hub_content_path();
    if let Ok(raw) = fs::read_to_string(&path) {
        if let Ok(c) = serde_json::from_str::<HubContent>(&raw) {
            return c;
        }
    }
    HubContent::default()
}

pub fn load_marketplace_catalog_disk() -> serde_json::Value {
    let path = marketplace_catalog_path();
    if let Ok(raw) = fs::read_to_string(&path) {
        if let Ok(v) = serde_json::from_str(&raw) {
            return v;
        }
    }
    json_fallback_catalog()
}

fn json_fallback_catalog() -> serde_json::Value {
    serde_json::json!({
        "apiVersion": 1,
        "updatedAt": chrono::Utc::now().to_rfc3339(),
        "items": []
    })
}

pub async fn get_hub_content() -> impl Responder {
    HttpResponse::Ok().json(load_hub_content_disk())
}

pub async fn put_hub_content(req: HttpRequest, body: web::Json<HubContent>) -> impl Responder {
    if !hub_admin_ok(&req) {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Invalid admin token".into(),
        });
    }
    let root = hub_data_root();
    if let Err(e) = fs::create_dir_all(&root) {
        log::error!("hub mkdir: {e}");
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Storage error".into(),
        });
    }
    match fs::write(
        hub_content_path(),
        serde_json::to_string_pretty(&body.into_inner()).unwrap_or_default(),
    ) {
        Ok(_) => HttpResponse::NoContent().finish(),
        Err(e) => {
            log::error!("hub write: {e}");
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Write failed".into(),
            })
        }
    }
}

pub async fn get_marketplace_catalog() -> impl Responder {
    HttpResponse::Ok().json(load_marketplace_catalog_disk())
}

pub async fn put_marketplace_catalog(
    req: HttpRequest,
    body: web::Json<serde_json::Value>,
) -> impl Responder {
    if !hub_admin_ok(&req) {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Invalid admin token".into(),
        });
    }
    let root = hub_data_root();
    if let Err(e) = fs::create_dir_all(&root) {
        log::error!("hub mkdir: {e}");
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Storage error".into(),
        });
    }
    match fs::write(
        marketplace_catalog_path(),
        serde_json::to_string_pretty(&body.into_inner()).unwrap_or_default(),
    ) {
        Ok(_) => HttpResponse::NoContent().finish(),
        Err(e) => {
            log::error!("marketplace write: {e}");
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Write failed".into(),
            })
        }
    }
}

pub fn ensure_dirs() {
    let _ = fs::create_dir_all(hub_data_root());
}
