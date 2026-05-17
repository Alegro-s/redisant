
use actix_web::{HttpResponse, Responder};
use serde_json::json;

pub async fn health() -> impl Responder {
    HttpResponse::Ok().json(json!({
        "product": "WaypointMetric",
        "version": env!("CARGO_PKG_VERSION"),
        "api": "v1",
        "role": "infrastructure_and_observability_for_apps",
        "audience": "business_owners_and_developers",
        "lynx_hub_public_site": "https://lynx-hub.ru",
        "lynx_cloud_console": "https://lynx-cloud.ru",
        "not_in_scope": "lynx_engine_editor_binary_studio_core",
        "lynx_cloud": "engine_manifest_artifacts_cloud_projects_same_api_host",
        "developer_platform": {
            "ingest_metrics_logs": "POST /api/waypoint/ingest",
            "ingest_dev_events_channels": "performance, brandformance, smm, reputation, analytics, web_dev, design, storage",
            "developer_events_api": "GET /api/waypoint/developer-events",
            "network_drive_registry": "CRUD /api/waypoint/network-drives (S3/WebDAV/NFS/SMB/ftp/timeweb_s3/custom)",
            "baas_duplicate": "/waypointmetric/v1/baas/* mirrors authenticated BaaS SQL/REST/object storage."
        },
        "note": "BaaS дублирует /me/baas/* под /waypointmetric/v1/baas/* для отдельного шлюза."
    }))
}
