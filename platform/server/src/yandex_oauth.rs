//! Yandex ID OAuth для Waypoint Metric (опционально, через env).

use actix_web::{web, HttpRequest, HttpResponse, Responder};
use serde::Deserialize;
use std::env;

use crate::ErrorResponse;

fn configured() -> Option<(String, String)> {
    let client_id = env::var("YANDEX_OAUTH_CLIENT_ID").ok().filter(|s| !s.trim().is_empty())?;
    let redirect = env::var("YANDEX_OAUTH_REDIRECT_URI")
        .ok()
        .filter(|s| !s.trim().is_empty())?;
    Some((client_id, redirect))
}

pub async fn yandex_start() -> impl Responder {
    let Some((client_id, redirect_uri)) = configured() else {
        return HttpResponse::ServiceUnavailable().json(ErrorResponse {
            error: "Yandex OAuth не настроен на сервере (YANDEX_OAUTH_CLIENT_ID, YANDEX_OAUTH_REDIRECT_URI)."
                .into(),
        });
    };
    let url = format!(
        "https://oauth.yandex.ru/authorize?response_type=code&client_id={}&redirect_uri={}",
        urlencoding::encode(&client_id),
        urlencoding::encode(&redirect_uri),
    );
    HttpResponse::Found()
        .append_header(("Location", url))
        .finish()
}

#[derive(Deserialize)]
pub struct YandexCallbackQuery {
    code: Option<String>,
    error: Option<String>,
}

pub async fn yandex_callback(query: web::Query<YandexCallbackQuery>, _req: HttpRequest) -> impl Responder {
    if query.error.is_some() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: query.error.clone().unwrap_or_else(|| "yandex_denied".into()),
        });
    }
    let Some(_code) = query.code.as_ref().filter(|c| !c.is_empty()) else {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "missing code".into(),
        });
    };
    HttpResponse::NotImplemented().json(serde_json::json!({
        "error": "Yandex token exchange в разработке",
        "hint": "Задайте YANDEX_OAUTH_CLIENT_SECRET и завершите обмен code→token в yandex_oauth.rs",
    }))
}
