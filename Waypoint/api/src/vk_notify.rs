use sqlx::PgPool;
use uuid::Uuid;

const MAX_ATTEMPTS: i32 = 8;

pub async fn notify_user_metric_alert(pool: &PgPool, user_id: Uuid, title: &str, body: &str) {
    if let Err(e) = sqlx::query(
        r#"INSERT INTO vk_notify_queue (user_id, title, body)
           VALUES ($1, $2, $3)"#,
    )
    .bind(user_id)
    .bind(title)
    .bind(body)
    .execute(pool)
    .await
    {
        log::error!("vk_notify_queue insert: {}", e);
    }
}

fn vk_group_token() -> Option<String> {
    match std::env::var("VK_GROUP_TOKEN") {
        Ok(t) if !t.trim().is_empty() => Some(t),
        _ => None,
    }
}

async fn send_vk_message(peer_id: i64, text: &str) -> Result<(), String> {
    let token = vk_group_token().ok_or_else(|| "VK_GROUP_TOKEN not set".to_string())?;
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(8))
        .build()
        .map_err(|e| e.to_string())?;

    let random_id: i64 = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);

    let resp = client
        .post("https://api.vk.com/method/messages.send")
        .form(&[
            ("peer_id", peer_id.to_string()),
            ("message", text.to_string()),
            ("access_token", token),
            ("v", "5.131".to_string()),
            ("random_id", random_id.to_string()),
        ])
        .send()
        .await
        .map_err(|e| e.to_string())?;

    let status = resp.status();
    let body = resp.text().await.unwrap_or_default();
    if !status.is_success() {
        return Err(format!("HTTP {}: {}", status, body.chars().take(200).collect::<String>()));
    }
    if body.contains("\"error\"") {
        return Err(body.chars().take(300).collect());
    }
    Ok(())
}

pub async fn process_queue_batch(pool: &PgPool, limit: i64) -> Result<usize, sqlx::Error> {
    let rows: Vec<(Uuid, Uuid, String, String, i32)> = sqlx::query_as(
        r#"SELECT id, user_id, title, body, attempts
           FROM vk_notify_queue
           WHERE next_attempt_at <= now() AND attempts < $1
           ORDER BY created_at ASC
           LIMIT $2"#,
    )
    .bind(MAX_ATTEMPTS)
    .bind(limit)
    .fetch_all(pool)
    .await?;

    let mut done = 0usize;
    for (qid, user_id, title, body, attempts) in rows {
        let peer: Option<(i64,)> =
            sqlx::query_as("SELECT peer_id FROM user_vk_peers WHERE user_id = $1")
                .bind(user_id)
                .fetch_optional(pool)
                .await?;

        let Some((peer_id,)) = peer else {
            let _ = sqlx::query("DELETE FROM vk_notify_queue WHERE id = $1")
                .bind(qid)
                .execute(pool)
                .await;
            continue;
        };

        let text = format!("{}\n{}", title, body);
        match send_vk_message(peer_id, &text).await {
            Ok(()) => {
                let _ = sqlx::query("DELETE FROM vk_notify_queue WHERE id = $1")
                    .bind(qid)
                    .execute(pool)
                    .await;
                done += 1;
            }
            Err(err) => {
                let next_try = attempts + 1;
                let backoff_secs: i64 = (2_i64)
                    .saturating_pow(next_try.clamp(1, 6) as u32)
                    .min(3600);
                if next_try >= MAX_ATTEMPTS {
                    let _ = sqlx::query(
                        r#"INSERT INTO vk_notify_dead (user_id, title, body, attempts, last_error)
                           VALUES ($1, $2, $3, $4, $5)"#,
                    )
                    .bind(user_id)
                    .bind(&title)
                    .bind(&body)
                    .bind(next_try)
                    .bind(&err)
                    .execute(pool)
                    .await;
                    let _ = sqlx::query("DELETE FROM vk_notify_queue WHERE id = $1")
                        .bind(qid)
                        .execute(pool)
                        .await;
                } else {
                    let _ = sqlx::query(
                        r#"UPDATE vk_notify_queue
                           SET attempts = $1,
                               last_error = $2,
                               next_attempt_at = now() + ($3 * interval '1 second')
                           WHERE id = $4"#,
                    )
                    .bind(next_try)
                    .bind(&err)
                    .bind(backoff_secs)
                    .bind(qid)
                    .execute(pool)
                    .await;
                }
            }
        }
    }
    Ok(done)
}

pub async fn run_worker(pool: PgPool) {
    let mut interval = tokio::time::interval(std::time::Duration::from_secs(10));
    loop {
        interval.tick().await;
        if vk_group_token().is_none() {
            continue;
        }
        match process_queue_batch(&pool, 25).await {
            Ok(n) if n > 0 => log::debug!("vk_notify: sent {}", n),
            Ok(_) => {}
            Err(e) => log::error!("vk_notify worker: {}", e),
        }
    }
}

pub async fn integration_health(pool: &PgPool) -> serde_json::Value {
    let pending: i64 = sqlx::query_scalar(
        "SELECT COUNT(*)::bigint FROM vk_notify_queue WHERE attempts < $1",
    )
    .bind(MAX_ATTEMPTS)
    .fetch_one(pool)
    .await
    .unwrap_or(0);

    let dead_recent: i64 = sqlx::query_scalar(
        "SELECT COUNT(*)::bigint FROM vk_notify_dead WHERE created_at > now() - interval '24 hours'",
    )
    .fetch_one(pool)
    .await
    .unwrap_or(0);

    let bot_secret = std::env::var("VK_BOT_SECRET")
        .map(|s| !s.trim().is_empty())
        .unwrap_or(false);
    let group_tok = vk_group_token().is_some();

    serde_json::json!({
        "vk_bot_secret_configured": bot_secret,
        "vk_group_token_configured": group_tok,
        "notify_queue_depth": pending,
        "notify_dead_24h": dead_recent,
    })
}
