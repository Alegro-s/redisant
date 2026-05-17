
use crate::{access, get_user_id_from_jwt_str, AppState};
use actix_web::{web, Error, HttpRequest, HttpResponse};
use actix_ws::Message;
use futures_util::StreamExt;
use serde_json::Value;
use std::collections::HashMap;
use std::sync::Mutex;
use tokio::sync::broadcast;
use uuid::Uuid;

use crate::scene_ws::token_from_ws_req;

const CAP: usize = 256;

pub struct StudioCollab {
    rooms: Mutex<HashMap<Uuid, broadcast::Sender<Vec<u8>>>>,
}

impl StudioCollab {
    pub fn new() -> Self {
        Self {
            rooms: Mutex::new(HashMap::new()),
        }
    }

    pub fn get_tx(&self, project_id: Uuid) -> broadcast::Sender<Vec<u8>> {
        let mut g = self.rooms.lock().unwrap();
        g.entry(project_id)
            .or_insert_with(|| broadcast::channel(CAP).0)
            .clone()
    }

    pub fn broadcast_json(&self, project_id: Uuid, v: Value) {
        let tx = self.get_tx(project_id);
        let _ = tx.send(v.to_string().into_bytes());
    }
}

pub async fn studio_ws_handler(
    state: web::Data<AppState>,
    req: HttpRequest,
    stream: web::Payload,
    path: web::Path<Uuid>,
) -> Result<HttpResponse, Error> {
    let jwt_secret =
        std::env::var("JWT_SECRET").map_err(|_| actix_web::error::ErrorInternalServerError("config"))?;
    let token = token_from_ws_req(&req).ok_or_else(|| actix_web::error::ErrorUnauthorized("Missing token"))?;
    let user_id = get_user_id_from_jwt_str(&token, &jwt_secret).ok_or_else(|| {
        actix_web::error::ErrorUnauthorized("Invalid token")
    })?;

    let project_id = path.into_inner();
    if !access::user_can_read_project(&state.pool, Some(user_id), project_id)
        .await
        .unwrap_or(false)
    {
        return Err(actix_web::error::ErrorForbidden("no access"));
    }

    let tx = state.studio_collab.get_tx(project_id);
    let mut rx = tx.subscribe();

    let (res, mut session, mut msg_stream) = actix_ws::handle(&req, stream)?;

    actix_web::rt::spawn(async move {
        loop {
            tokio::select! {
                incoming = msg_stream.next() => {
                    match incoming {
                        Some(Ok(Message::Text(t))) => {
                            let _ = tx.send(t.to_string().into_bytes());
                        }
                        Some(Ok(Message::Binary(b))) => {
                            let _ = tx.send(b.to_vec());
                        }
                        Some(Ok(Message::Ping(p))) => {
                            let _ = session.pong(&p).await;
                        }
                        Some(Ok(Message::Close(_))) | None => break,
                        _ => {}
                    }
                }
                br = rx.recv() => {
                    match br {
                        Ok(b) => {
                            if session.binary(b).await.is_err() {
                                break;
                            }
                        }
                        Err(_) => break,
                    }
                }
            }
        }
        let _ = session.close(None).await;
    });

    Ok(res)
}
