use actix_web::{web, HttpResponse, Responder};

use crate::engine_releases::{build_manifest, fetch_manifest_from_url, EngineManifest};
use crate::{AppState, ErrorResponse};

pub async fn manifest_by_slug(state: web::Data<AppState>, path: web::Path<String>) -> impl Responder {
    let slug = path.into_inner();
    let sl = slug.trim().to_lowercase();
    if sl.is_empty() || sl == "engine" || sl == "nexus-engine" {
        let m = build_manifest(&state.pool).await;
        return HttpResponse::Ok().json(m);
    }

    let row: Option<(String, Option<String>)> =
        sqlx::query_as("SELECT manifest_url, recommended_version FROM platform_artifact_channel WHERE slug = $1")
            .bind(&sl)
            .fetch_optional(&state.pool)
            .await
            .unwrap_or(None);

    let Some((url, rec_override)) = row else {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: format!("Unknown artifact channel slug: {sl}"),
        });
    };

    let url = url.trim();
    if url.is_empty() {
        return HttpResponse::Ok().json(EngineManifest {
            releases: vec![],
            recommended_version: rec_override,
            source: Some(format!("channel:{sl}:empty_url")),
        });
    }

    match fetch_manifest_from_url(url).await {
        Ok(mut m) => {
            m.recommended_version = rec_override.or(m.recommended_version);
            m.source = Some(format!("channel:{sl}"));
            HttpResponse::Ok().json(m)
        }
        Err(e) => {
            log::warn!("artifact channel {sl} fetch failed: {e}");
            HttpResponse::Ok().json(EngineManifest {
                releases: vec![],
                recommended_version: rec_override,
                source: Some(format!("channel:{sl}:error")),
            })
        }
    }
}
