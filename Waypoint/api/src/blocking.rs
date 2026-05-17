
use anyhow::{Context, Result};
use bcrypt::{hash, verify, DEFAULT_COST};
use std::fs;
use std::path::PathBuf;

pub async fn bcrypt_hash_password(password: &str) -> Result<String> {
    let p = password.to_string();
    tokio::task::spawn_blocking(move || hash(&p, DEFAULT_COST))
        .await
        .context("bcrypt hash join")?
        .map_err(|e| anyhow::anyhow!(e))
}

pub async fn bcrypt_verify_password(password: &str, password_hash: &str) -> Result<bool> {
    let p = password.to_string();
    let h = password_hash.to_string();
    tokio::task::spawn_blocking(move || verify(&p, &h))
        .await
        .context("bcrypt verify join")?
        .map_err(|e| anyhow::anyhow!(e))
}

pub async fn write_upload_file(
    parent_dirs: Option<PathBuf>,
    full_path: String,
    data: Vec<u8>,
) -> std::io::Result<()> {
    match tokio::task::spawn_blocking(move || -> std::io::Result<()> {
        if let Some(ref p) = parent_dirs {
            fs::create_dir_all(p)?;
        }
        fs::write(&full_path, &data)?;
        Ok(())
    })
    .await
    {
        Ok(r) => r,
        Err(e) => Err(std::io::Error::new(std::io::ErrorKind::Other, e)),
    }
}

pub async fn remove_file(path: String) {
    let _ = tokio::task::spawn_blocking(move || fs::remove_file(path)).await;
}

pub async fn read_file_bytes(full_path: String) -> std::io::Result<Vec<u8>> {
    match tokio::task::spawn_blocking(move || fs::read(&full_path)).await {
        Ok(r) => r,
        Err(e) => Err(std::io::Error::new(std::io::ErrorKind::Other, e)),
    }
}
