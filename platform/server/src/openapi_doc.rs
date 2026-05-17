
use actix_web::{HttpResponse, Responder};

pub async fn openapi_json() -> impl Responder {
    HttpResponse::Ok()
        .content_type("application/json")
        .body(include_str!("../openapi.json"))
}

pub async fn swagger_ui() -> impl Responder {
    HttpResponse::Ok()
        .content_type("text/html; charset=utf-8")
        .body(include_str!("../swagger-ui.html"))
}
