use axum::{
    extract::State,
    http::{header, StatusCode},
    response::IntoResponse,
    Json,
};
use serde::{Deserialize, Serialize};
use std::{path::PathBuf, sync::Arc};
use tokio::sync::RwLock;

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

#[derive(Clone)]
pub struct HubState {
    pub data_dir: PathBuf,
    pub content: Arc<RwLock<HubContent>>,
}

pub fn hub_content_path(data_dir: &PathBuf) -> PathBuf {
    data_dir.join("hub_content.json")
}

pub fn load_hub_content(data_dir: &PathBuf) -> HubContent {
    let path = hub_content_path(data_dir);
    if let Ok(raw) = std::fs::read_to_string(&path) {
        if let Ok(c) = serde_json::from_str::<HubContent>(&raw) {
            return c;
        }
    }
    HubContent::default()
}

pub async fn persist_hub_content(st: &HubState) -> anyhow::Result<()> {
    let c = st.content.read().await.clone();
    let path = hub_content_path(&st.data_dir);
    let json = serde_json::to_string_pretty(&c)?;
    std::fs::write(path, json)?;
    Ok(())
}

pub async fn get_hub_content(State(st): State<HubState>) -> impl IntoResponse {
    let c = st.content.read().await.clone();
    Json(c)
}

pub async fn put_hub_content(
    State(st): State<HubState>,
    Json(body): Json<HubContent>,
) -> Result<StatusCode, StatusCode> {
    let token = std::env::var("LYNX_HUB_ADMIN_TOKEN").unwrap_or_default();
    if token.is_empty() {
        return Err(StatusCode::FORBIDDEN);
    }
    *st.content.write().await = body;
    persist_hub_content(&st).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::NO_CONTENT)
}

pub async fn get_hub_content_public(State(st): State<HubState>) -> impl IntoResponse {
    let c = st.content.read().await.clone();
    (
        [(header::ACCESS_CONTROL_ALLOW_ORIGIN, "*")],
        Json(c),
    )
}
