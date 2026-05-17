
use sqlx::PgPool;
use crate::{hash_admin_activation_key, generate_admin_activation_key};

const POOL_TARGET: i64 = 20;
const REFILL_THRESHOLD: i64 = 10;

pub async fn ensure_admin_key_pool(pool: &PgPool) {
    let count: Result<(i64,), sqlx::Error> = sqlx::query_as(
        r#"SELECT COUNT(*)::bigint FROM admin_activation_keys
           WHERE key_kind = 'admin'
             AND pool_generated = true
             AND used_at IS NULL
             AND revoked_at IS NULL"#,
    )
    .fetch_one(pool)
    .await;

    let n = match count {
        Ok((c,)) => c,
        Err(e) => {
            log::error!("ensure_admin_key_pool count: {}", e);
            return;
        }
    };

    if n >= REFILL_THRESHOLD {
        return;
    }

    let need = POOL_TARGET - n;
    if need <= 0 {
        return;
    }

    for _ in 0..need {
        let raw = generate_admin_activation_key();
        let key_hash = hash_admin_activation_key(&raw);
        let key_prefix = raw[..8].to_string();
        if let Err(e) = sqlx::query(
            r#"INSERT INTO admin_activation_keys
               (key_hash, key_prefix, note, created_by, expires_at, key_kind, pool_generated)
               VALUES ($1, $2, NULL, NULL, NULL, 'admin', true)"#,
        )
        .bind(&key_hash)
        .bind(&key_prefix)
        .execute(pool)
        .await
        {
            log::error!("ensure_admin_key_pool insert: {}", e);
            break;
        }
    }
    log::info!("ensure_admin_key_pool: ensured pool (added up to {} keys)", need);
}
