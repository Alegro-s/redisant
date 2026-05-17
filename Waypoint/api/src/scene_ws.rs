
use crate::scene_collab_crdt;
use actix_web::{web, Error, HttpRequest, HttpResponse};
use actix_ws::Message;
use futures_util::StreamExt;
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tokio::sync::broadcast;
use uuid::Uuid;

use crate::{access, get_user_id_from_jwt_str, AppState};

const CAP: usize = 256;

pub struct SceneCollab {
    rooms: Mutex<HashMap<String, broadcast::Sender<Vec<u8>>>>,
    crdt: Mutex<HashMap<String, Arc<Mutex<scene_collab_crdt::CrdtRoom>>>>,
}

impl SceneCollab {
    pub fn new() -> Self {
        Self {
            rooms: Mutex::new(HashMap::new()),
            crdt: Mutex::new(HashMap::new()),
        }
    }

    pub fn get_tx(&self, key: &str) -> broadcast::Sender<Vec<u8>> {
        let mut g = self.rooms.lock().unwrap();
        g.entry(key.to_string())
            .or_insert_with(|| broadcast::channel(CAP).0)
            .clone()
    }

    pub fn crdt_room_handle(&self, key: &str) -> Arc<Mutex<scene_collab_crdt::CrdtRoom>> {
        let mut g = self.crdt.lock().unwrap();
        g.entry(key.to_string())
            .or_insert_with(|| Arc::new(Mutex::new(scene_collab_crdt::CrdtRoom::default())))
            .clone()
    }

    pub fn room_key(project_id: Uuid, scene_id: &str) -> String {
        format!("{}:{}", project_id, scene_id)
    }
}

pub(crate) fn token_from_ws_req(req: &HttpRequest) -> Option<String> {
    if let Some(h) = req.headers().get("Authorization") {
        if let Ok(s) = h.to_str() {
            if let Some(t) = s.strip_prefix("Bearer ") {
                let t = t.trim();
                if !t.is_empty() {
                    return Some(t.to_string());
                }
            }
        }
    }
    let q = req.uri().query()?;
    for pair in q.split('&') {
        let mut it = pair.splitn(2, '=');
        let k = it.next()?;
        if k == "access_token" {
            let v = it.next().unwrap_or("");
            let decoded = urlencoding::decode(v).ok()?.into_owned();
            if !decoded.is_empty() {
                return Some(decoded);
            }
        }
    }
    None
}

#[derive(Deserialize)]
struct TextOtMsg {
    target: String,
    base_rev: u64,
    op: scene_collab_crdt::OtOpIn,
}

pub async fn scene_ws_handler(
    state: web::Data<AppState>,
    req: HttpRequest,
    stream: web::Payload,
    path: web::Path<(Uuid, String)>,
) -> Result<HttpResponse, Error> {
    let jwt_secret = std::env::var("JWT_SECRET").map_err(|_| actix_web::error::ErrorInternalServerError("config"))?;
    let token = token_from_ws_req(&req).ok_or_else(|| actix_web::error::ErrorUnauthorized("Missing token"))?;
    let user_id = get_user_id_from_jwt_str(&token, &jwt_secret).ok_or_else(|| {
        actix_web::error::ErrorUnauthorized("Invalid token")
    })?;

    let (project_id, scene_id) = path.into_inner();
    if !access::user_can_write_project(&state.pool, user_id, project_id)
        .await
        .unwrap_or(false)
    {
        return Err(actix_web::error::ErrorForbidden("no write access"));
    }

    let key = SceneCollab::room_key(project_id, &scene_id);
    let tx = state.scene_collab.get_tx(&key);
    let mut rx = tx.subscribe();
    let collab = state.scene_collab.clone();

    let (res, mut session, mut msg_stream) = actix_ws::handle(&req, stream)?;

    actix_web::rt::spawn(async move {
        loop {
            tokio::select! {
                incoming = msg_stream.next() => {
                    match incoming {
                        Some(Ok(Message::Text(t))) => {
                            if let Ok(v) = serde_json::from_str::<Value>(&t) {
                                let ty = v.get("type").and_then(|x| x.as_str());
                                match ty {
                                    Some("nexus_scene_crdt") => {
                                        let ops: Vec<scene_collab_crdt::CrdtOpIn> =
                                            serde_json::from_value(v.get("ops").cloned().unwrap_or(json!([])))
                                                .unwrap_or_default();
                                        let h = collab.crdt_room_handle(&key);
                                        let mut room = h.lock().unwrap();
                                        room.apply_lww_ops(&ops);
                                        let merged = json!({
                                            "type": "nexus_scene_crdt_merged",
                                            "sceneId": v.get("sceneId").and_then(|x| x.as_str()).unwrap_or(&scene_id),
                                            "fromUserId": user_id.to_string(),
                                            "content": room.content.clone(),
                                            "revision": room.revision,
                                        });
                                        let _ = tx.send(merged.to_string().into_bytes());
                                        continue;
                                    }
                                    Some("nexus_scene_sync") => {
                                        if let (Some(content), Some(rev)) = (
                                            v.get("content"),
                                            v.get("revision").and_then(|x| x.as_i64()),
                                        ) {
                                            let h = collab.crdt_room_handle(&key);
                                            let mut room = h.lock().unwrap();
                                            if let Some(obj) = content.as_object() {
                                                let _ = room.replace_if_newer(Value::Object(obj.clone()), rev);
                                            }
                                        }
                                    }
                                    Some("nexus_text_ot") => {
                                        if let Ok(body) = serde_json::from_value::<TextOtMsg>(v.clone()) {
                                            let h = collab.crdt_room_handle(&key);
                                            let mut room = h.lock().unwrap();
                                            match room.apply_text_ot(&body.target, body.base_rev, &body.op) {
                                                Ok(new_rev) => {
                                                    let out = json!({
                                                        "type": "nexus_text_ot_broadcast",
                                                        "target": body.target,
                                                        "rev": new_rev,
                                                        "op": body.op,
                                                        "fromUserId": user_id.to_string(),
                                                    });
                                                    let _ = tx.send(out.to_string().into_bytes());
                                                }
                                                Err(e) => {
                                                    let err = json!({
                                                        "type": "nexus_text_ot_reject",
                                                        "error": e,
                                                        "target": body.target,
                                                    });
                                                    let _ = session.text(err.to_string()).await;
                                                }
                                            }
                                            continue;
                                        }
                                    }
                                    _ => {}
                                }
                            }
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
