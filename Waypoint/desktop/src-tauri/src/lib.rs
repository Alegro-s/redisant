use std::process::Command;
use std::sync::Mutex;
static PENDING_DEEP_LINK: Mutex<Option<String>> = Mutex::new(None);

#[tauri::command]
fn secure_set(key: String, value: String) -> Result<(), String> {
    let entry = keyring::Entry::new("waypoint-desktop", &key).map_err(|e| e.to_string())?;
    entry.set_password(&value).map_err(|e| e.to_string())
}

#[tauri::command]
fn secure_get(key: String) -> Result<String, String> {
    let entry = keyring::Entry::new("waypoint-desktop", &key).map_err(|e| e.to_string())?;
    entry.get_password().map_err(|_| "not found".into())
}

#[tauri::command]
fn docker_ps() -> Result<Vec<String>, String> {
    let out = if cfg!(target_os = "windows") {
        Command::new("docker")
            .args(["ps", "--format", "{{.Names}}\t{{.Status}}"])
            .output()
    } else {
        Command::new("docker")
            .args(["ps", "--format", "{{.Names}}\t{{.Status}}"])
            .output()
    }
    .map_err(|e| format!("docker not available: {e}"))?;
    if !out.status.success() {
        return Err(String::from_utf8_lossy(&out.stderr).into_owned());
    }
    let text = String::from_utf8_lossy(&out.stdout);
    Ok(text.lines().map(|s| s.to_string()).filter(|s| !s.is_empty()).collect())
}

#[tauri::command]
fn run_shell(command: String) -> Result<String, String> {
    let out = if cfg!(target_os = "windows") {
        Command::new("powershell")
            .args(["-NoProfile", "-Command", &command])
            .output()
    } else {
        Command::new("sh")
            .args(["-c", &command])
            .output()
    }
    .map_err(|e| e.to_string())?;
    let mut s = String::from_utf8_lossy(&out.stdout).into_owned();
    if !out.stderr.is_empty() {
        s.push_str(&String::from_utf8_lossy(&out.stderr));
    }
    Ok(s)
}

#[tauri::command]
fn take_pending_deep_link() -> Option<String> {
    PENDING_DEEP_LINK.lock().ok()?.take()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .invoke_handler(tauri::generate_handler![
            secure_set,
            secure_get,
            docker_ps,
            run_shell,
            take_pending_deep_link
        ])
        .setup(|_app| {
            if let Some(url) = std::env::args().nth(1) {
                if url.starts_with("waypoint://") {
                    if let Ok(mut g) = PENDING_DEEP_LINK.lock() {
                        *g = Some(url);
                    }
                }
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
