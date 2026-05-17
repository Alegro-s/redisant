
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct IngestPayload {
    pub timestamp: Option<DateTime<Utc>>,
    #[serde(default)]
    pub metrics: Vec<PayloadMetric>,
    #[serde(default)]
    pub logs: Option<Vec<PayloadLog>>,
    #[serde(default)]
    pub events: Vec<PayloadDevEvent>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct PayloadMetric {
    pub name: String,
    pub value: f64,
    #[serde(default)]
    pub tags: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct PayloadLog {
    pub level: String,
    pub message: String,
    #[serde(default)]
    pub tags: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct PayloadDevEvent {
    pub channel: String,
    pub event: String,
    #[serde(default)]
    pub value: Option<f64>,
    #[serde(default)]
    pub properties: Option<serde_json::Value>,
}

pub const MAX_METRIC_NAME_LEN: usize = 256;
pub const MAX_LOG_MESSAGE_LEN: usize = 8192;
pub const MAX_DEV_EVENT_NAME_LEN: usize = 256;
pub const MAX_DEV_EVENTS_PER_REQUEST: usize = 2000;

pub static DEV_EVENT_CHANNELS: &[&str] = &[
    "performance",
    "brandformance",
    "smm",
    "reputation",
    "analytics",
    "web_dev",
    "design",
    "storage",
];

pub fn metric_acceptable(m: &PayloadMetric) -> bool {
    let n = m.name.trim();
    !n.is_empty() && n.len() <= MAX_METRIC_NAME_LEN && m.value.is_finite()
}

pub fn log_acceptable(l: &PayloadLog) -> bool {
    let msg = l.message.trim();
    !msg.is_empty() && msg.len() <= MAX_LOG_MESSAGE_LEN
}

pub fn log_triggers_alert(level: &str) -> bool {
    matches!(
        level.to_lowercase().as_str(),
        "error" | "critical" | "fatal"
    )
}

pub fn dev_event_acceptable(e: &PayloadDevEvent) -> bool {
    let ch = e.channel.trim().to_lowercase();
    if ch.is_empty() || ch.len() > 64 {
        return false;
    }
    if !DEV_EVENT_CHANNELS.iter().any(|c| *c == ch.as_str()) {
        return false;
    }
    let ev = e.event.trim();
    !ev.is_empty() && ev.len() <= MAX_DEV_EVENT_NAME_LEN
        && e.value.map(|v| v.is_finite()).unwrap_or(true)
}

pub fn normalize_dev_channel(raw: &str) -> String {
    raw.trim().to_lowercase()
}
