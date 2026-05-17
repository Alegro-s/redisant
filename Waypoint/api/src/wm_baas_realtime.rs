
use actix_web::{web, Error, HttpRequest, HttpResponse};
use actix_ws::Message;
use futures_util::StreamExt;
use serde_json::json;
use sqlx::postgres::PgListener;

use crate::scene_ws::token_from_ws_req;
use crate::{get_user_id_from_jwt_str, AppState};

pub async fn baas_realtime_ws(
    state: web::Data<AppState>,
    req: HttpRequest,
    stream: web::Payload,
) -> Result<HttpResponse, Error> {
    let jwt_secret =
        std::env::var("JWT_SECRET").map_err(|_| actix_web::error::ErrorInternalServerError("config"))?;
    let token = token_from_ws_req(&req).ok_or_else(|| actix_web::error::ErrorUnauthorized("Missing token"))?;
    let user_id = get_user_id_from_jwt_str(&token, &jwt_secret).ok_or_else(|| {
        actix_web::error::ErrorUnauthorized("Invalid token")
    })?;

    let pool = state.pool.clone();
    let uid_str = user_id.to_string();

    let (res, mut session, mut msg_stream) = actix_ws::handle(&req, stream)?;

    actix_web::rt::spawn(async move {
        let mut listener = match PgListener::connect_with(&pool).await {
            Ok(l) => l,
            Err(e) => {
                log::error!("wm_baas PgListener connect: {}", e);
                let _ = session
                    .text(json!({"type":"error","message":"listen unavailable"}).to_string())
                    .await;
                return;
            }
        };
        if let Err(e) = listener.listen("wm_baas").await {
            log::error!("wm_baas LISTEN: {}", e);
            return;
        }
        let hello = json!({
            "type": "wm_baas_subscribed",
            "channel": "wm_baas",
            "user_id": uid_str,
        });
        if session.text(hello.to_string()).await.is_err() {
            return;
        }

        loop {
            tokio::select! {
                incoming = msg_stream.next() => {
                    match incoming {
                        Some(Ok(Message::Ping(p))) => {
                            if session.pong(&p).await.is_err() { break; }
                        }
                        Some(Ok(Message::Close(_))) | None => break,
                        _ => {}
                    }
                }
                notif = listener.recv() => {
                    match notif {
                        Ok(n) => {
                            let payload = n.payload();
                            if let Ok(v) = serde_json::from_str::<serde_json::Value>(payload) {
                                if v.get("u").and_then(|x| x.as_str()) == Some(uid_str.as_str()) {
                                    let envelope = json!({
                                        "type": "wm_baas_event",
                                        "payload": v,
                                    });
                                    if session.text(envelope.to_string()).await.is_err() {
                                        break;
                                    }
                                }
                            }
                        }
                        Err(e) => {
                            log::warn!("wm_baas recv: {}", e);
                            break;
                        }
                    }
                }
            }
        }
    });

    Ok(res)
}
