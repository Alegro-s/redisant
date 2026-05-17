use actix_web::{web, HttpResponse, Responder, HttpRequest};
use serde::Deserialize;
use crate::authz;

#[derive(Debug, Deserialize)]
pub struct AnalyzeRequest {
    pub target_type: String,
    pub target: String,
    #[serde(default)]
    pub ingest: Option<crate::waypoint::ingest_payload::IngestPayload>,
}

pub async fn analyze(
    req: HttpRequest,
    pool: web::Data<sqlx::PgPool>,
    payload: web::Json<AnalyzeRequest>,
) -> impl Responder {
    if let Err(resp) = authz::require_staff(pool.get_ref(), &req).await {
        return resp;
    }

    if let Some(ref ingest) = payload.ingest {
        let mut report = crate::waypoint::ingest_analysis::dry_run_report(ingest);
        if let Some(map) = report.as_object_mut() {
            map.insert(
                "via".into(),
                serde_json::json!("waypoint_ai_analyze_ingest_preview"),
            );
        }
        return HttpResponse::Ok().json(report);
    }

    HttpResponse::Ok().json(serde_json::json!({
        "analysis": "Передайте поле ingest с телом как у POST /api/waypoint/ingest — dry-run включая metrics, logs и events (каналы performance/smm/storage/…). Либо target_type/target для будущего AI поверх хранилища.",
        "target_type": payload.target_type,
        "target": payload.target,
    }))
}