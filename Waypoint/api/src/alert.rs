
use serde_json::json;

pub fn metric_email_alert_async(title: &str, body: &str) {
    let Ok(to) = std::env::var("WAYPOINT_ALERT_EMAIL_TO") else {
        return;
    };
    if to.trim().is_empty() {
        return;
    }
    let url = match std::env::var("OTP_WEBHOOK_URL") {
        Ok(u) if !u.trim().is_empty() => u,
        _ => {
            log::warn!("WAYPOINT_ALERT_EMAIL_TO set but OTP_WEBHOOK_URL empty — skip email alert");
            return;
        }
    };
    let secret = std::env::var("OTP_WEBHOOK_SECRET").unwrap_or_default();
    let title = title.to_string();
    let body = body.to_string();
    let to = to.trim().to_string();
    tokio::spawn(async move {
        let client = match reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(15))
            .build()
        {
            Ok(c) => c,
            Err(e) => {
                log::error!("metric email alert client: {}", e);
                return;
            }
        };
        let payload = json!({
            "purpose": "waypoint_metric_alert",
            "channel": "email",
            "to_email": to,
            "alert_subject": title,
            "alert_body": body,
        });
        match client
            .post(&url)
            .header("Content-Type", "application/json")
            .header("X-Nexus-Webhook-Secret", &secret)
            .json(&payload)
            .send()
            .await
        {
            Ok(resp) => {
                let status = resp.status();
                let txt = resp.text().await.unwrap_or_default();
                let preview: String = txt.chars().take(400).collect();
                if status.is_success() {
                    log::info!("waypoint metric email alert OK: {}", preview);
                } else {
                    log::warn!(
                        "waypoint metric email alert HTTP {}: {}",
                        status,
                        preview
                    );
                }
            }
            Err(e) => log::error!("waypoint metric email alert: {}", e),
        }
    });
}

pub fn webhook_async(title: &str, body: &str) {
    let Ok(url) = std::env::var("ALERT_WEBHOOK_URL") else {
        return;
    };
    if url.is_empty() {
        return;
    }
    let text = format!("{} — {}", title, body);
    let payload = json!({ "text": text });
    let url = url;
    tokio::spawn(async move {
        let client = match reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(8))
            .build()
        {
            Ok(c) => c,
            Err(_) => return,
        };
        let _ = client.post(url).json(&payload).send().await;
    });
}
