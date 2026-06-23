mod arcade;
mod auth;
mod hub;
mod marketplace;

use anyhow::Context;
use axum::{
    routing::{get, post},
    Router,
};
use hub::{load_hub_content, HubState};
use marketplace::{load_licenses, persist_licenses, MarketplaceState};
use std::{env, net::SocketAddr, path::PathBuf, sync::Arc};
use tokio::sync::RwLock;
use tower_http::cors::{Any, CorsLayer};
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env().add_directive("lynx_server=info".parse()?))
        .init();

    let data_dir = env::var("LYNX_SERVER_DATA")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("data"));
    std::fs::create_dir_all(data_dir.join("packages"))?;
    std::fs::create_dir_all(data_dir.join("arcade_carts"))?;

    let st = MarketplaceState {
        data_dir: data_dir.clone(),
        licenses: Arc::new(RwLock::new(load_licenses(&data_dir))),
    };

    let hub_content = load_hub_content(&data_dir);
    let hub_st = HubState {
        data_dir: data_dir.clone(),
        content: Arc::new(RwLock::new(hub_content)),
    };

    let arcade_st = arcade::ArcadeState {
        data_dir: data_dir.clone(),
    };

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let marketplace = Router::new()
        .route("/catalog", get(marketplace::get_catalog))
        .route("/items/:id/claim", post(marketplace::claim_item))
        .route("/items/:id/download", get(marketplace::download_item));

    let hub = Router::new()
        .route("/content", get(hub::get_hub_content_public).put(hub::put_hub_content));

    let arcade = Router::new()
        .route("/catalog", get(arcade::get_catalog))
        .route("/carts", post(arcade::upload_cart))
        .route("/carts/:id", get(arcade::get_cart_meta))
        .route("/carts/:id/download", get(arcade::download_cart));

    let app = Router::new()
        .route("/health", get(|| async { "ok" }))
        .merge(
            Router::new()
                .nest("/v1/marketplace", marketplace)
                .with_state(st.clone()),
        )
        .merge(
            Router::new()
                .nest("/v1/hub", hub)
                .with_state(hub_st.clone()),
        )
        .merge(
            Router::new()
                .nest("/v1/arcade", arcade)
                .with_state(arcade_st),
        )
        .layer(cors);

    let port: u16 = env::var("LYNX_SERVER_PORT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(8080);
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    tracing::info!("lynx-server listening on http://{addr}");
    tracing::info!("data_dir = {}", data_dir.display());

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app)
        .with_graceful_shutdown(async move {
            let _ = tokio::signal::ctrl_c().await;
            let _ = persist_licenses(&st).await;
        })
        .await
        .context("serve")?;
    Ok(())
}
