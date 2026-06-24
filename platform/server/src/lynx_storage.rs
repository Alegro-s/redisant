//! Lynx object storage — S3-compatible (twcstorage.ru).

use actix_multipart::Multipart;
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use futures_util::StreamExt;
use hmac::{Hmac, Mac};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sha2::{Digest, Sha256};
use std::env;

use crate::{authz, AppState, ErrorResponse};

type HmacSha256 = Hmac<Sha256>;

#[derive(Clone)]
struct S3Config {
    endpoint: String,
    bucket: String,
    access_key: String,
    secret_key: String,
    region: String,
    public_base: String,
}

fn s3_config() -> Result<S3Config, &'static str> {
    let access_key = env::var("LYNX_S3_ACCESS_KEY")
        .or_else(|_| env::var("S3_ACCESS_KEY"))
        .map_err(|_| "S3 not configured")?;
    let secret_key = env::var("LYNX_S3_SECRET_KEY")
        .or_else(|_| env::var("S3_SECRET_KEY"))
        .map_err(|_| "S3 not configured")?;
    if access_key.is_empty() || secret_key.is_empty() {
        return Err("S3 not configured");
    }
    let endpoint = env::var("LYNX_S3_ENDPOINT")
        .unwrap_or_else(|_| "https://s3.twcstorage.ru".into())
        .trim_end_matches('/')
        .to_string();
    let bucket = env::var("LYNX_S3_BUCKET")
        .unwrap_or_else(|_| "bc39a46d-ee3d-4707-9e3f-9529afb602da".into());
    let region = env::var("LYNX_S3_REGION").unwrap_or_else(|_| "ru-1".into());
    let public_base = env::var("LYNX_S3_PUBLIC_BASE")
        .unwrap_or_else(|_| format!("{endpoint}/{bucket}"));
    Ok(S3Config {
        endpoint,
        bucket,
        access_key,
        secret_key,
        region,
        public_base,
    })
}

fn sha256_hex(data: &[u8]) -> String {
    let mut h = Sha256::new();
    h.update(data);
    format!("{:x}", h.finalize())
}

fn hmac_sha256(key: &[u8], data: &[u8]) -> Vec<u8> {
    let mut mac = HmacSha256::new_from_slice(key).expect("hmac key");
    mac.update(data);
    mac.finalize().into_bytes().to_vec()
}

fn signing_key(secret: &str, date: &str, region: &str, service: &str) -> Vec<u8> {
    let k_date = hmac_sha256(format!("AWS4{secret}").as_bytes(), date.as_bytes());
    let k_region = hmac_sha256(&k_date, region.as_bytes());
    let k_service = hmac_sha256(&k_region, service.as_bytes());
    hmac_sha256(&k_service, b"aws4_request")
}

pub fn public_url_for_key(key: &str) -> Result<String, &'static str> {
    let cfg = s3_config()?;
    Ok(format!(
        "{}/{}",
        cfg.public_base.trim_end_matches('/'),
        key.trim_start_matches('/')
    ))
}

pub fn presigned_put_url(key: &str, content_type: &str, expires_secs: u64) -> Result<String, &'static str> {
    let cfg = s3_config()?;
    let key = key.trim_start_matches('/');
    if key.contains("..") {
        return Err("invalid key");
    }
    let now = chrono::Utc::now();
    let amz_date = now.format("%Y%m%dT%H%M%SZ").to_string();
    let date_stamp = now.format("%Y%m%d").to_string();
    let host = cfg
        .endpoint
        .trim_start_matches("https://")
        .trim_start_matches("http://");
    let credential_scope = format!("{}/{}/s3/aws4_request", date_stamp, cfg.region);
    let credential = format!("{}/{}", cfg.access_key, credential_scope);
    let signed_headers = "content-type;host";
    let canonical_uri = format!("/{}/{}", cfg.bucket, key);
    let canonical_query = format!(
        "X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential={}&X-Amz-Date={}&X-Amz-Expires={}&X-Amz-SignedHeaders={}",
        urlencoding::encode(&credential),
        amz_date,
        expires_secs,
        signed_headers
    );
    let canonical_request = format!(
        "PUT\n{canonical_uri}\n{canonical_query}\ncontent-type:{content_type}\nhost:{host}\n\n{signed_headers}\nUNSIGNED-PAYLOAD"
    );
    let string_to_sign = format!(
        "AWS4-HMAC-SHA256\n{amz_date}\n{credential_scope}\n{}",
        sha256_hex(canonical_request.as_bytes())
    );
    let sig_key = signing_key(&cfg.secret_key, &date_stamp, &cfg.region, "s3");
    let signature = hex::encode(hmac_sha256(&sig_key, string_to_sign.as_bytes()));
    Ok(format!(
        "{}/{}/{}?{}&X-Amz-Signature={}",
        cfg.endpoint, cfg.bucket, key, canonical_query, signature
    ))
}

pub async fn s3_put_bytes(key: &str, bytes: &[u8], content_type: &str) -> Result<String, String> {
    let _ = s3_config().map_err(|e| e.to_string())?;
    let key = key.trim_start_matches('/');
    let url = presigned_put_url(key, content_type, 300).map_err(|e| e.to_string())?;
    let client = reqwest::Client::new();
    let res = client
        .put(&url)
        .header("Content-Type", content_type)
        .body(bytes.to_vec())
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if !res.status().is_success() {
        let body = res.text().await.unwrap_or_default();
        return Err(format!("S3 upload failed: {}", body));
    }
    public_url_for_key(key).map_err(|e| e.to_string())
}

fn validate_storage_key(key: &str) -> bool {
    let k = key.trim();
    !k.is_empty()
        && k.len() <= 512
        && !k.contains("..")
        && (k.starts_with("deploy/lynx/") || k.starts_with("deploy/sites/latest/"))
}

#[derive(Deserialize)]
pub struct PresignBody {
    pub key: String,
    #[serde(default)]
    pub content_type: Option<String>,
}

#[derive(Serialize)]
pub struct PresignResponse {
    pub upload_url: String,
    pub public_url: String,
    pub method: &'static str,
}

pub async fn admin_presign(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<PresignBody>,
) -> impl Responder {
    if let Err(resp) = authz::require_lynx_ops(&state.pool, &req).await {
        return resp;
    }
    let key = body.key.trim().to_string();
    if !validate_storage_key(&key) {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "key must start with deploy/lynx/ or deploy/sites/latest/".into(),
        });
    }
    let ct = body
        .content_type
        .as_deref()
        .unwrap_or("application/octet-stream");
    match presigned_put_url(&key, ct, 3600) {
        Ok(upload_url) => {
            let public_url = public_url_for_key(&key).unwrap_or_else(|_| upload_url.clone());
            HttpResponse::Ok().json(PresignResponse {
                upload_url,
                public_url,
                method: "PUT",
            })
        }
        Err(e) => HttpResponse::ServiceUnavailable().json(ErrorResponse {
            error: format!("Storage unavailable: {e}"),
        }),
    }
}

pub async fn admin_upload_multipart(
    state: web::Data<AppState>,
    req: HttpRequest,
    mut payload: Multipart,
) -> impl Responder {
    if let Err(resp) = authz::require_lynx_ops(&state.pool, &req).await {
        return resp;
    }
    let mut key = String::new();
    let mut content_type = "application/octet-stream".to_string();
    let mut bytes: Vec<u8> = Vec::new();

    while let Some(Ok(mut field)) = payload.next().await {
        let name = field
            .content_disposition()
            .and_then(|cd| cd.get_name().map(|s| s.to_string()))
            .unwrap_or_default();
        match name.as_str() {
            "key" => {
                let mut buf = Vec::new();
                while let Some(Ok(chunk)) = field.next().await {
                    buf.extend_from_slice(&chunk);
                }
                key = String::from_utf8_lossy(&buf).trim().to_string();
            }
            "content_type" | "contentType" => {
                let mut buf = Vec::new();
                while let Some(Ok(chunk)) = field.next().await {
                    buf.extend_from_slice(&chunk);
                }
                content_type = String::from_utf8_lossy(&buf).trim().to_string();
            }
            "file" => {
                if let Some(ct) = field.content_type() {
                    content_type = ct.to_string();
                }
                while let Some(Ok(chunk)) = field.next().await {
                    bytes.extend_from_slice(&chunk);
                }
            }
            _ => {}
        }
    }

    if key.is_empty() || bytes.is_empty() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "fields key and file required".into(),
        });
    }
    if !validate_storage_key(&key) {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "invalid key prefix".into(),
        });
    }

    match s3_put_bytes(&key, &bytes, &content_type).await {
        Ok(public_url) => HttpResponse::Ok().json(json!({
            "ok": true,
            "public_url": public_url,
            "sha256": sha256_hex(&bytes),
            "size_bytes": bytes.len(),
        })),
        Err(e) => HttpResponse::ServiceUnavailable().json(ErrorResponse { error: e }),
    }
}

#[derive(Deserialize)]
pub struct RegisterEngineArtifactBody {
    pub version: String,
    pub platform: String,
    #[serde(default)]
    pub channel: Option<String>,
    pub artifact_url: String,
    #[serde(default)]
    pub sha256: Option<String>,
    #[serde(default)]
    pub size_bytes: Option<i64>,
    #[serde(default)]
    pub notes: Option<String>,
    #[serde(default)]
    pub set_recommended: Option<bool>,
}

pub async fn admin_register_engine_artifact(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<RegisterEngineArtifactBody>,
) -> impl Responder {
    if let Err(resp) = authz::require_lynx_ops(&state.pool, &req).await {
        return resp;
    }
    let b = body.into_inner();
    let version = b.version.trim();
    let platform = b.platform.trim();
    if version.is_empty() || platform.is_empty() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "version and platform required".into(),
        });
    }
    let channel = b.channel.as_deref().unwrap_or("stable").trim();
    let manifest_key = env::var("LYNX_ENGINE_MANIFEST_S3_KEY")
        .unwrap_or_else(|_| "deploy/sites/latest/dist/downloads/engine-manifest.json".into());

    let mut manifest = crate::engine_releases::load_manifest_for_admin(&state.pool).await;
    manifest.releases.retain(|r| !(r.version == version && r.artifacts.contains_key(platform)));
    let mut artifacts = std::collections::HashMap::new();
    artifacts.insert(
        platform.to_string(),
        crate::engine_releases::EngineArtifact {
            url: b.artifact_url.clone(),
            sha256: b.sha256.clone(),
        },
    );
    manifest.releases.push(crate::engine_releases::EngineRelease {
        version: version.to_string(),
        notes: b.notes.clone(),
        channel: Some(channel.to_string()),
        artifacts,
    });
    if b.set_recommended.unwrap_or(false) {
        manifest.recommended_version = Some(version.to_string());
    }

    let json_bytes = serde_json::to_vec_pretty(&manifest).unwrap_or_default();
    match s3_put_bytes(&manifest_key, &json_bytes, "application/json").await {
        Ok(public_url) => {
            let _ = sqlx::query(
                "UPDATE nexus_engine_policy SET manifest_url = $1, recommended_version = COALESCE($2, recommended_version), updated_at = now() WHERE id = 1",
            )
            .bind(&public_url)
            .bind(if b.set_recommended.unwrap_or(false) {
                Some(version.to_string())
            } else {
                None::<String>
            })
            .execute(&state.pool)
            .await;
            HttpResponse::Ok().json(json!({
                "ok": true,
                "manifest_url": public_url,
                "recommended_version": manifest.recommended_version,
            }))
        }
        Err(e) => HttpResponse::ServiceUnavailable().json(ErrorResponse { error: e }),
    }
}
