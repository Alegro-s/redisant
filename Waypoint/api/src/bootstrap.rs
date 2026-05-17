
use sqlx::PgPool;
use std::env;
use uuid::Uuid;

const DEFAULT_BOOTSTRAP_OWNER_EMAIL: &str = "igor-vinogradov04@yandex.ru";

fn bootstrap_skipped_by_env() -> bool {
    matches!(
        env::var("NEXUS_BOOTSTRAP_SKIP").ok().as_deref(),
        Some("1") | Some("true") | Some("yes")
    )
}

async fn grant_both_realms(pool: &PgPool, user_id: Uuid) {
    for realm in ["nexus", "metric"] {
        match sqlx::query(
            "INSERT INTO user_realm (user_id, realm) VALUES ($1, $2) ON CONFLICT DO NOTHING",
        )
        .bind(user_id)
        .bind(realm)
        .execute(pool)
        .await
        {
            Ok(_) => {}
            Err(e) => log::error!("bootstrap: user_realm {} for {}: {}", realm, user_id, e),
        }
    }
}

pub async fn promote_first_nexus_if_configured(pool: &PgPool) {
    if bootstrap_skipped_by_env() {
        log::info!("NEXUS_BOOTSTRAP_SKIP: первичный bootstrap nexus отключён");
        return;
    }

    let email = env::var("NEXUS_BOOTSTRAP_ADMIN_EMAIL")
        .ok()
        .map(|s| s.trim().to_lowercase())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| DEFAULT_BOOTSTRAP_OWNER_EMAIL.trim().to_lowercase());

    if email.is_empty() {
        return;
    }

    let nexus_count: Result<(i64,), sqlx::Error> =
        sqlx::query_as("SELECT COUNT(*)::bigint FROM users WHERE role = 'nexus'")
            .fetch_one(pool)
            .await;

    match nexus_count {
        Ok((n,)) if n > 0 => {
            log::info!(
                "nexus bootstrap: skip — already {} nexus user(s) in database",
                n
            );
            return;
        }
        Err(e) => {
            log::error!("bootstrap nexus count: {}", e);
            return;
        }
        Ok(_) => {}
    }

    let promoted_id: Option<Uuid> = match sqlx::query_scalar(
        r#"UPDATE users SET role = 'nexus', updated_at = NOW()
           WHERE lower(trim(email)) = $1
             AND role IN ('user', 'admin')
           RETURNING id"#,
    )
    .bind(&email)
    .fetch_optional(pool)
    .await
    {
        Ok(id) => id,
        Err(e) => {
            log::error!("bootstrap nexus update: {}", e);
            return;
        }
    };

    if let Some(uid) = promoted_id {
        grant_both_realms(pool, uid).await;
        log::warn!(
            "nexus bootstrap: '{}' → role nexus + realms (metric, nexus). Env переопределяет встроенный email; для чужого деплоя — NEXUS_BOOTSTRAP_SKIP=1 или смените константу в bootstrap.rs.",
            email
        );
        return;
    }

    log::warn!(
        "nexus bootstrap: email '{}' — пользователь не найден или уже не user/admin. Зарегистрируйте этот email, затем перезапустите API.",
        email
    );
}
