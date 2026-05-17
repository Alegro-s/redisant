//! VK OAuth — заготовка (подключение после регистрации приложения ВКонтакте).

use actix_web::{HttpResponse, Responder, web};

pub async fn vk_start() -> impl Responder {
    HttpResponse::NotImplemented().json(serde_json::json!({
        "error": "VK OAuth в разработке",
        "hint": "Задайте VK_OAUTH_CLIENT_ID и VK_OAUTH_REDIRECT_URI, затем включите маршруты в auth-api",
        "routes": ["/auth/vk/start", "/auth/vk/callback"]
    }))
}

pub async fn vk_callback(_query: web::Query<serde_json::Value>) -> impl Responder {
    HttpResponse::NotImplemented().json(serde_json::json!({
        "error": "VK OAuth callback ещё не реализован"
    }))
}
