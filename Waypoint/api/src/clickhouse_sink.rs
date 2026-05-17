
use chrono::{DateTime, Utc};
use serde_json::Value;
use uuid::Uuid;

fn base_url() -> Option<String> {
    std::env::var("CLICKHOUSE_HTTP_URL")
        .ok()
        .filter(|s| !s.trim().is_empty())
        .map(|s| s.trim_end_matches('/').to_string())
}

pub fn enabled() -> bool {
    base_url().is_some()
}

pub fn spawn_sink_metrics(
    client: reqwest::Client,
    api_key_id: Uuid,
    user_id: Uuid,
    name: &str,
    value: f64,
    tags: &Value,
    ts: DateTime<Utc>,
) {
    let Some(base) = base_url() else {
        return;
    };
    let tags_str = tags.to_string();
    let line = serde_json::json!({
        "api_key_id": api_key_id.to_string(),
        "user_id": user_id.to_string(),
        "name": name,
        "value": value,
        "tags": tags_str,
        "ts": ts.to_rfc3339_opts(chrono::SecondsFormat::Millis, true),
    })
    .to_string();
    tokio::spawn(async move {
        let url = format!(
            "{}/?query={}",
            base,
            urlencoding::encode("INSERT INTO nexus_ingested_metrics FORMAT JSONEachRow")
        );
        let _ = client
            .post(&url)
            .header("Content-Type", "application/json")
            .body(line + "\n")
            .send()
            .await;
    });
}

pub fn spawn_sink_log(
    client: reqwest::Client,
    api_key_id: Uuid,
    user_id: Uuid,
    level: &str,
    message: &str,
    tags: &Value,
    ts: DateTime<Utc>,
) {
    let Some(base) = base_url() else {
        return;
    };
    let tags_str = tags.to_string();
    let line = serde_json::json!({
        "api_key_id": api_key_id.to_string(),
        "user_id": user_id.to_string(),
        "level": level,
        "message": message,
        "tags": tags_str,
        "ts": ts.to_rfc3339_opts(chrono::SecondsFormat::Millis, true),
    })
    .to_string();
    tokio::spawn(async move {
        let url = format!(
            "{}/?query={}",
            base,
            urlencoding::encode("INSERT INTO nexus_ingested_logs FORMAT JSONEachRow")
        );
        let _ = client
            .post(&url)
            .header("Content-Type", "application/json")
            .body(line + "\n")
            .send()
            .await;
    });
}
