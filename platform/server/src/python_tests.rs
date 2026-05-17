use actix_multipart::Multipart;
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use futures_util::StreamExt as _;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::collections::HashMap;
use std::env;
use std::path::PathBuf;
use std::process::Stdio;
use std::sync::{Arc, OnceLock};
use tokio::fs;
use tokio::io::AsyncWriteExt;
use tokio::process::Command;
use tokio::sync::Semaphore;
use tokio::time::{sleep, Duration, Instant};
use uuid::Uuid;

use crate::{get_user_id_from_token, AppState, ErrorResponse};

#[derive(Serialize)]
struct ModuleTestRunOut {
    id: String,
    label: String,
    git_url: Option<String>,
    demo_mode: Option<String>,
    status: String,
    summary: Option<serde_json::Value>,
    created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Deserialize)]
pub struct LogQuery {
    max_bytes: Option<usize>,
}

#[derive(Deserialize)]
pub struct CompareQuery {
    ids: Option<String>,
    limit: Option<usize>,
    sort_by: Option<String>,
    sort_dir: Option<String>,
}

fn max_parallel_jobs() -> usize {
    env::var("MODULE_TEST_MAX_PARALLEL")
        .ok()
        .and_then(|s| s.parse::<usize>().ok())
        .filter(|v| *v > 0)
        .unwrap_or(1)
}

fn runner_semaphore() -> &'static Arc<Semaphore> {
    static SEM: OnceLock<Arc<Semaphore>> = OnceLock::new();
    SEM.get_or_init(|| Arc::new(Semaphore::new(max_parallel_jobs())))
}

fn jwt_secret() -> Result<String, HttpResponse> {
    env::var("JWT_SECRET").map_err(|_| {
        HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Server configuration error".into(),
        })
    })
}

fn upload_root() -> String {
    env::var("MODULE_TEST_UPLOAD_DIR").unwrap_or_else(|_| "./uploads/module-tests".into())
}

fn max_zip_bytes() -> usize {
    env::var("MODULE_TEST_MAX_ZIP_MB")
        .ok()
        .and_then(|s| s.parse::<usize>().ok())
        .unwrap_or(4096)
        * 1024
        * 1024
}

fn max_unpacked_bytes() -> u64 {
    env::var("MODULE_TEST_MAX_UNPACKED_MB")
        .ok()
        .and_then(|s| s.parse::<u64>().ok())
        .unwrap_or(10 * 1024)
        * 1024
        * 1024
}

fn eta_from_stage(stage: &str, percent: i32, created_at: chrono::DateTime<chrono::Utc>) -> i64 {
    let stage_pct = match stage {
        "upload" => 1,
        "queued" => 5,
        "extract" => 20,
        "install_tools" => 40,
        "scan" => 60,
        "tests" => 80,
        "report" => 95,
        _ => percent.max(1),
    };
    let elapsed = (chrono::Utc::now() - created_at).num_seconds().max(1);
    let speed = (stage_pct as f64 / elapsed as f64).max(0.01);
    ((100 - stage_pct).max(0) as f64 / speed).round() as i64
}

async fn historical_eta_seconds(
    state: &web::Data<AppState>,
    uid: Uuid,
    language: &str,
    archive_size_bytes: Option<i64>,
    stage_percent: i32,
) -> Option<i64> {
    let rows = sqlx::query_as::<_, (Option<serde_json::Value>,)>(
        r#"SELECT summary
           FROM module_test_runs
           WHERE user_id=$1
             AND status IN ('done','failed')
             AND COALESCE(summary->>'language','') = $2
             AND summary IS NOT NULL
           ORDER BY created_at DESC
           LIMIT 40"#,
    )
    .bind(uid)
    .bind(language)
    .fetch_all(&state.pool)
    .await
    .ok()?;
    let mut samples: Vec<(f64, f64)> = Vec::new(); // (size_bytes, elapsed_secs)
    for (summary_opt,) in rows {
        let Some(summary) = summary_opt else { continue };
        let elapsed = summary
            .get("elapsed_seconds")
            .and_then(|v| v.as_f64())
            .or_else(|| summary.get("elapsed_seconds").and_then(|v| v.as_i64()).map(|v| v as f64));
        let size = summary
            .get("archive_size_bytes")
            .and_then(|v| v.as_f64())
            .or_else(|| summary.get("archive_size_bytes").and_then(|v| v.as_i64()).map(|v| v as f64));
        if let (Some(e), Some(s)) = (elapsed, size) {
            if e > 0.0 && s > 0.0 {
                samples.push((s, e));
            }
        }
    }
    if samples.is_empty() {
        return None;
    }
    let target_size = archive_size_bytes.unwrap_or(0).max(0) as f64;
    let predicted_total = if target_size > 0.0 {
        let mut weighted_sum = 0.0f64;
        let mut weighted_den = 0.0f64;
        for (size, elapsed) in samples {
            let ratio = elapsed / size.max(1.0);
            let dist = ((size - target_size).abs() / target_size.max(1.0)).min(5.0);
            let weight = 1.0 / (1.0 + dist);
            weighted_sum += ratio * weight;
            weighted_den += weight;
        }
        if weighted_den > 0.0 {
            (weighted_sum / weighted_den) * target_size
        } else {
            return None;
        }
    } else {
        let avg = samples.iter().map(|(_, e)| *e).sum::<f64>() / samples.len() as f64;
        avg
    };
    let remaining = predicted_total * ((100 - stage_percent.max(1)) as f64 / 100.0);
    Some(remaining.max(1.0).round() as i64)
}

async fn update_run_status(
    state: &web::Data<AppState>,
    run_id: Uuid,
    status: &str,
    summary: Option<serde_json::Value>,
) {
    let _ = sqlx::query("UPDATE module_test_runs SET status = $1, summary = COALESCE($2, summary) WHERE id = $3")
        .bind(status)
        .bind(summary)
        .bind(run_id)
        .execute(&state.pool)
        .await;
}

async fn set_progress(
    state: &web::Data<AppState>,
    run_id: Uuid,
    status: &str,
    stage: &str,
    percent: i32,
    extra: HashMap<&str, serde_json::Value>,
) {
    let mut obj = serde_json::Map::new();
    obj.insert("stage".into(), json!(stage));
    obj.insert("percent".into(), json!(percent));
    for (k, v) in extra {
        obj.insert(k.to_string(), v);
    }
    update_run_status(state, run_id, status, Some(serde_json::Value::Object(obj))).await;
}

fn build_runner_script(language: &str, strict_offline: bool) -> String {
    if language == "rust" {
        return r#"
set -e
python - <<'PY'
import json, pathlib, subprocess, zipfile
root = pathlib.Path("/job"); zip_path = root / "source.zip"; work = root / "work"; out = root / "out"
out.mkdir(parents=True, exist_ok=True)
if work.exists():
    import shutil; shutil.rmtree(work)
work.mkdir(parents=True, exist_ok=True)
def save_stage(name, p):
    (out/"progress.json").write_text(json.dumps({"stage":name,"percent":p}, ensure_ascii=False))
save_stage("extract", 20)
with zipfile.ZipFile(zip_path, "r") as zf:
    infos = zf.infolist()
    total_unpacked = sum(i.file_size for i in infos)
    if total_unpacked > __MAX_UNPACKED__:
        (out/"summary.json").write_text(json.dumps({"error":"zip bomb protection: unpacked size limit exceeded","total_unpacked":total_unpacked}, ensure_ascii=False))
        raise SystemExit(9)
    if len(infos) > 200000:
        (out/"summary.json").write_text(json.dumps({"error":"zip bomb protection: file count limit exceeded","file_count":len(infos)}, ensure_ascii=False))
        raise SystemExit(9)
    zf.extractall(work)
def run(cmd):
    p = subprocess.run(cmd, cwd=str(work), capture_output=True, text=True)
    return {"cmd":cmd,"exit_code":p.returncode,"stdout":(p.stdout or "")[-12000:],"stderr":(p.stderr or "")[-12000:]}
save_stage("install_tools", 40)
install = {"skipped": __STRICT__}
if not __STRICT__:
    install = run(["cargo","install","cargo-audit"])
save_stage("scan", 60)
fmt = run(["cargo","fmt","--all","--","--check"])
clippy = run(["cargo","clippy","--all-targets","--all-features","--","-D","warnings"])
save_stage("tests", 80)
tests = run(["cargo","test","--all","--","--nocapture"])
audit = run(["cargo","audit"]) if not __STRICT__ else {"cmd":["cargo","audit"],"exit_code":0,"stdout":"skipped (strict offline)","stderr":""}
quality = {"fmt":fmt,"clippy":clippy,"tests":tests,"cargo_audit":audit,"install_tools":install}
summary = {
 "runner":"rust:1.78",
 "language":"rust",
 "strict_offline": __STRICT__,
 "quality_tools": {"fmt_exit_code":fmt["exit_code"],"clippy_exit_code":clippy["exit_code"],"tests_exit_code":tests["exit_code"]},
 "dependency_security": {"cargo_audit_exit_code": audit["exit_code"]},
 "exit_code": tests["exit_code"],
}
(out/"summary.json").write_text(json.dumps(summary, ensure_ascii=False))
(out/"quality.json").write_text(json.dumps(quality, ensure_ascii=False))
(out/"deps_security.json").write_text(json.dumps({"cargo_audit": audit}, ensure_ascii=False))
report = {"title":"NEXUS Diploma Report", "summary":summary, "quality":quality}
(out/"diploma_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2))
save_stage("report", 95)
sys_exit = tests["exit_code"] if tests["exit_code"] != 0 else max(fmt["exit_code"], clippy["exit_code"])
raise SystemExit(sys_exit)
PY
"#
        .replace("__STRICT__", if strict_offline { "True" } else { "False" })
        .replace("__MAX_UNPACKED__", &max_unpacked_bytes().to_string());
    }
    r#"
set -e
python - <<'PY'
import json, os, pathlib, subprocess, sys, zipfile

root = pathlib.Path("/job")
zip_path = root / "source.zip"
work = root / "work"
out = root / "out"
out.mkdir(parents=True, exist_ok=True)
if work.exists():
    import shutil
    shutil.rmtree(work)
work.mkdir(parents=True, exist_ok=True)

with zipfile.ZipFile(zip_path, "r") as zf:
    infos = zf.infolist()
    total_unpacked = sum(i.file_size for i in infos)
    if total_unpacked > __MAX_UNPACKED__:
        (out/"summary.json").write_text(json.dumps({"error":"zip bomb protection: unpacked size limit exceeded","total_unpacked":total_unpacked}, ensure_ascii=False))
        raise SystemExit(9)
    if len(infos) > 200000:
        (out/"summary.json").write_text(json.dumps({"error":"zip bomb protection: file count limit exceeded","file_count":len(infos)}, ensure_ascii=False))
        raise SystemExit(9)
    zf.extractall(work)
def save_stage(name, p):
    (out/"progress.json").write_text(json.dumps({"stage":name,"percent":p}, ensure_ascii=False))
save_stage("extract", 20)

files = [p for p in work.rglob("*") if p.is_file()]
total_size = sum(p.stat().st_size for p in files)
py_only = [p for p in files if p.suffix.lower() == ".py"]
python_lines = sum(len(p.read_text(errors="ignore").splitlines()) for p in py_only)

tool_hits = {
    "pytest": any(p.name.startswith("test_") or p.name == "pytest.ini" for p in files),
    "poetry": any(p.name == "poetry.lock" or p.name == "pyproject.toml" for p in files),
    "pip": any(p.name == "requirements.txt" for p in files),
    "docker": any(p.name.lower() == "dockerfile" for p in files),
    "github_actions": any(".github/workflows" in str(p).replace("\\", "/") for p in files),
}

detected = []
for f in files:
    n = f.name.lower()
    if n in ("manage.py",):
        detected.append("django")
    if n in ("app.py", "wsgi.py", "asgi.py"):
        detected.append("web-app")
    if n == "requirements.txt":
        txt = f.read_text(errors="ignore").lower()
        for lib in ("fastapi", "flask", "django", "torch", "tensorflow", "streamlit", "opencv-python", "pandas"):
            if lib in txt:
                detected.append(lib)
detected = sorted(set(detected))

def run_cmd(cmd, cwd):
    try:
        p = subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True)
        return {
            "cmd": cmd,
            "exit_code": p.returncode,
            "stdout": (p.stdout or "")[-12000:],
            "stderr": (p.stderr or "")[-12000:],
        }
    except Exception as e:
        return {"cmd": cmd, "exit_code": 127, "stdout": "", "stderr": str(e)}

save_stage("install_tools", 40)
install = {"skipped": __STRICT__}
if not __STRICT__:
    install = run_cmd(
        [sys.executable, "-m", "pip", "install", "--disable-pip-version-check", "-q", "ruff", "mypy", "bandit", "pip-audit", "reportlab"],
        work,
    )
quality = {
    "install_tools": install,
    "ruff": run_cmd([sys.executable, "-m", "ruff", "check", "."], work),
    "ruff_format": run_cmd([sys.executable, "-m", "ruff", "format", "--check", "."], work),
    "mypy": run_cmd([sys.executable, "-m", "mypy", ".", "--ignore-missing-imports"], work),
    "bandit": run_cmd([sys.executable, "-m", "bandit", "-r", "."], work),
}

save_stage("scan", 60)
if (work / "requirements.txt").exists():
    audit = run_cmd([sys.executable, "-m", "pip_audit", "-r", "requirements.txt", "-f", "json"], work)
else:
    audit = run_cmd([sys.executable, "-m", "pip_audit", "-f", "json"], work)

deps = {"pip_audit": audit}
vuln_count = 0
if isinstance(audit.get("stdout"), str) and audit["stdout"].strip().startswith("["):
    try:
        vuln = json.loads(audit["stdout"])
        vuln_count = sum(len(x.get("vulns", [])) for x in vuln if isinstance(x, dict))
    except Exception:
        pass

cmd = None
if any((work / x).exists() for x in ["pytest.ini", "pyproject.toml", "tox.ini"]) or any(p.name.startswith("test_") for p in files):
    cmd = [sys.executable, "-m", "pytest", "-q", "--maxfail=20"]
elif any(p.suffix == ".py" for p in files):
    cmd = [sys.executable, "-m", "compileall", "-q", "."]

exit_code = 0
save_stage("tests", 80)
if cmd:
    print("RUN:", " ".join(cmd), flush=True)
    r = subprocess.run(cmd, cwd=str(work))
    exit_code = r.returncode
else:
    print("No runnable python test entrypoint found; only static scan.", flush=True)

summary = {
    "files_count": len(files),
    "python_files_count": len(py_only),
    "python_source_lines": python_lines,
    "archive_size_bytes": total_size,
    "detected_devtools": tool_hits,
    "detected_stack": detected,
    "quality_tools": {
        "ruff_exit_code": quality["ruff"]["exit_code"],
        "ruff_format_exit_code": quality["ruff_format"]["exit_code"],
        "mypy_exit_code": quality["mypy"]["exit_code"],
        "bandit_exit_code": quality["bandit"]["exit_code"],
    },
    "dependency_security": {
        "pip_audit_exit_code": deps["pip_audit"]["exit_code"],
        "vulnerabilities_total": vuln_count,
    },
    "runner": "python:3.11-slim",
    "exit_code": exit_code,
}
(out / "summary.json").write_text(json.dumps(summary, ensure_ascii=False))
(out / "quality.json").write_text(json.dumps(quality, ensure_ascii=False))
(out / "deps_security.json").write_text(json.dumps(deps, ensure_ascii=False))

report = {
    "title": "NEXUS Diploma Report",
    "summary": summary,
    "quality": quality,
    "deps_security": deps,
}
(out / "diploma_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2))
save_stage("report", 95)

try:
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfgen import canvas
    pdf = canvas.Canvas(str(out / "diploma_report.pdf"), pagesize=A4)
    y = 800
    def line(txt):
        nonlocal y
        pdf.drawString(40, y, txt[:110])
        y -= 16
        if y < 40:
            pdf.showPage()
            y = 800
    line("NEXUS Diploma Testing Report")
    line(f"Files: {summary['files_count']}")
    line(f"Archive size(bytes): {summary['archive_size_bytes']}")
    line(f"Detected stack: {', '.join(summary['detected_stack']) if summary['detected_stack'] else '-'}")
    line(f"Devtools: {summary['detected_devtools']}")
    line(f"ruff={summary['quality_tools']['ruff_exit_code']}, ruff_format={summary['quality_tools']['ruff_format_exit_code']}, mypy={summary['quality_tools']['mypy_exit_code']}, bandit={summary['quality_tools']['bandit_exit_code']}")
    line(f"Python: {summary.get('python_files_count',0)} files, {summary.get('python_source_lines',0)} lines")
    line(f"pip-audit vulnerabilities: {summary['dependency_security']['vulnerabilities_total']}")
    line(f"runner exit code: {summary['exit_code']}")
    pdf.save()
except Exception as e:
    (out / "diploma_report_pdf_error.txt").write_text(str(e))

sys.exit(exit_code)
PY
"#
    .replace("__STRICT__", if strict_offline { "True" } else { "False" })
    .replace("__MAX_UNPACKED__", &max_unpacked_bytes().to_string())
}

async fn run_zip_test_job(
    state: web::Data<AppState>,
    run_id: Uuid,
    run_dir: PathBuf,
    language: String,
    strict_offline: bool,
) {
    let started_at = Instant::now();
    let _permit = match runner_semaphore().acquire().await {
        Ok(p) => p,
        Err(_) => return,
    };
    update_run_status(&state, run_id, "running", None).await;
    let mut extra = HashMap::new();
    extra.insert("language", json!(language));
    extra.insert("strict_offline", json!(strict_offline));
    set_progress(&state, run_id, "running", "queued", 5, extra).await;

    let logs_path = run_dir.join("runner.log");
    let out_dir = run_dir.join("out");
    let _ = fs::create_dir_all(&out_dir).await;

    let log_file = match std::fs::OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(true)
        .open(&logs_path)
    {
        Ok(f) => f,
        Err(e) => {
            update_run_status(
                &state,
                run_id,
                "failed",
                Some(json!({"error": format!("failed to create log file: {}", e)})),
            )
            .await;
            return;
        }
    };
    let log_file_err = match log_file.try_clone() {
        Ok(f) => f,
        Err(e) => {
            update_run_status(
                &state,
                run_id,
                "failed",
                Some(json!({"error": format!("failed to clone log file: {}", e)})),
            )
            .await;
            return;
        }
    };

    let script = build_runner_script(&language, strict_offline);
    let mut cmd = Command::new("docker");
    let docker_network = if strict_offline {
        "none".to_string()
    } else {
        env::var("MODULE_TEST_DOCKER_NETWORK").unwrap_or_else(|_| "bridge".into())
    };
    let image = if language == "rust" { "rust:1.78" } else { "python:3.11-slim" };
    cmd.arg("run")
        .arg("--rm")
        .arg("--network")
        .arg(docker_network)
        .arg("-m")
        .arg(env::var("MODULE_TEST_DOCKER_MEMORY").unwrap_or_else(|_| "4g".into()))
        .arg("--cpus")
        .arg(env::var("MODULE_TEST_DOCKER_CPUS").unwrap_or_else(|_| "2".into()))
        .arg("-v")
        .arg(format!("{}:/job", run_dir.to_string_lossy()))
        .arg("-w")
        .arg("/job")
        .arg(image)
        .arg("bash")
        .arg("-lc")
        .arg(script)
        .stdout(Stdio::from(log_file))
        .stderr(Stdio::from(log_file_err));

    let timeout_secs = env::var("MODULE_TEST_TIMEOUT_SECS")
        .ok()
        .and_then(|s| s.parse::<u64>().ok())
        .unwrap_or(3600);

    let mut child = match cmd.spawn() {
        Ok(c) => c,
        Err(e) => {
            update_run_status(
                &state,
                run_id,
                "failed",
                Some(json!({"error": format!("runner start error: {}", e)})),
            )
            .await;
            return;
        }
    };
    let deadline = Instant::now() + Duration::from_secs(timeout_secs);
    let progress_path = run_dir.join("out").join("progress.json");
    let status = loop {
        match child.try_wait() {
            Ok(Some(s)) => break s,
            Ok(None) => {
                if Instant::now() >= deadline {
                    let _ = child.kill().await;
                    update_run_status(
                        &state,
                        run_id,
                        "failed",
                        Some(json!({"error": "runner timeout"})),
                    )
                    .await;
                    return;
                }
                if let Ok(progress_raw) = fs::read_to_string(&progress_path).await {
                    if let Ok(v) = serde_json::from_str::<serde_json::Value>(&progress_raw) {
                        let stage = v.get("stage").and_then(|x| x.as_str()).unwrap_or("running");
                        let percent = v.get("percent").and_then(|x| x.as_i64()).unwrap_or(50) as i32;
                        let mut pextra = HashMap::new();
                        pextra.insert("language", json!(language));
                        pextra.insert("strict_offline", json!(strict_offline));
                        set_progress(&state, run_id, "running", stage, percent, pextra).await;
                    }
                }
                sleep(Duration::from_secs(2)).await;
            }
            Err(e) => {
                update_run_status(
                    &state,
                    run_id,
                    "failed",
                    Some(json!({"error": format!("runner wait error: {}", e)})),
                )
                .await;
                return;
            }
        }
    };
    if status.code().is_none() {
        update_run_status(
            &state,
            run_id,
            "failed",
            Some(json!({"error": "runner terminated by signal"})),
        )
        .await;
        return;
    }
    let mut extra_done = HashMap::new();
    extra_done.insert("language", json!(language));
    extra_done.insert("strict_offline", json!(strict_offline));
    set_progress(&state, run_id, "running", "report", 98, extra_done).await;

    let summary_path = run_dir.join("out").join("summary.json");
    let summary_val = match fs::read_to_string(&summary_path).await {
        Ok(s) => serde_json::from_str::<serde_json::Value>(&s).ok(),
        Err(_) => None,
    };
    let final_summary = match summary_val {
        Some(mut v) => {
            if let Some(obj) = v.as_object_mut() {
                obj.insert("docker_exit_code".into(), json!(status.code()));
                obj.insert("elapsed_seconds".into(), json!(started_at.elapsed().as_secs()));
            }
            Some(v)
        }
        None => Some(json!({
            "docker_exit_code": status.code(),
            "elapsed_seconds": started_at.elapsed().as_secs(),
            "note": "summary.json not produced"
        })),
    };
    let final_status = if status.success() { "done" } else { "failed" };
    update_run_status(&state, run_id, final_status, final_summary).await;
}

pub async fn upload_python_zip_test(
    state: web::Data<AppState>,
    req: HttpRequest,
    mut payload: Multipart,
) -> impl Responder {
    let secret = match jwt_secret() {
        Ok(v) => v,
        Err(e) => return e,
    };
    let uid = match get_user_id_from_token(&req, &secret) {
        Some(v) => v,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let mut label = String::from("Python ZIP test");
    let mut language = String::from("python");
    let mut network_mode = String::from("online");
    let mut zip_bytes: Vec<u8> = Vec::new();
    let max_bytes = max_zip_bytes();
    let mut filename = String::new();

    while let Some(Ok(mut field)) = payload.next().await {
        let cd = field.content_disposition().cloned();
        let name = cd.as_ref().and_then(|c| c.get_name()).unwrap_or("");
        if name == "label" {
            let mut chunks = Vec::new();
            while let Some(Ok(chunk)) = field.next().await {
                chunks.extend_from_slice(&chunk);
            }
            let txt = String::from_utf8_lossy(&chunks).trim().to_string();
            if !txt.is_empty() {
                label = txt;
            }
        } else if name == "language" {
            let mut chunks = Vec::new();
            while let Some(Ok(chunk)) = field.next().await {
                chunks.extend_from_slice(&chunk);
            }
            let txt = String::from_utf8_lossy(&chunks).trim().to_lowercase();
            if txt == "rust" || txt == "python" {
                language = txt;
            }
        } else if name == "network_mode" {
            let mut chunks = Vec::new();
            while let Some(Ok(chunk)) = field.next().await {
                chunks.extend_from_slice(&chunk);
            }
            let txt = String::from_utf8_lossy(&chunks).trim().to_lowercase();
            if txt == "strict" || txt == "online" {
                network_mode = txt;
            }
        } else if name == "zip" || name == "file" {
            filename = cd
                .as_ref()
                .and_then(|c| c.get_filename())
                .unwrap_or("")
                .to_string();
            while let Some(Ok(chunk)) = field.next().await {
                if zip_bytes.len().saturating_add(chunk.len()) > max_bytes {
                    return HttpResponse::BadRequest().json(ErrorResponse {
                        error: format!("ZIP too large (max {} MB)", max_bytes / 1024 / 1024),
                    });
                }
                zip_bytes.extend_from_slice(&chunk);
            }
        }
    }

    if zip_bytes.is_empty() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "ZIP file is required (multipart field: zip)".into(),
        });
    }
    if !filename.to_lowercase().ends_with(".zip") {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Only .zip is supported".into(),
        });
    }

    let run_id = Uuid::new_v4();
    let run_dir = PathBuf::from(upload_root()).join(run_id.to_string());
    if let Err(e) = fs::create_dir_all(&run_dir).await {
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: format!("Failed to prepare run dir: {}", e),
        });
    }
    let zip_path = run_dir.join("source.zip");
    match fs::File::create(&zip_path).await {
        Ok(mut f) => {
            if let Err(e) = f.write_all(&zip_bytes).await {
                return HttpResponse::InternalServerError().json(ErrorResponse {
                    error: format!("Failed to save zip: {}", e),
                });
            }
        }
        Err(e) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: format!("Failed to create zip file: {}", e),
            })
        }
    }

    let inserted = sqlx::query_as::<_, (Uuid,)>(
        r#"INSERT INTO module_test_runs (id, user_id, label, git_url, demo_mode, status, summary)
           VALUES ($1, $2, $3, NULL, $4, 'queued', $5) RETURNING id"#,
    )
    .bind(run_id)
    .bind(uid)
    .bind(label.trim())
    .bind(format!("{}_zip", language))
    .bind(json!({
        "stage":"upload",
        "percent": 1,
        "archive_size_bytes": zip_bytes.len(),
        "language": language,
        "strict_offline": network_mode == "strict",
    }))
    .fetch_one(&state.pool)
    .await;
    if inserted.is_err() {
        return HttpResponse::InternalServerError().json(ErrorResponse {
            error: "Failed to create test run".into(),
        });
    }

    let state_clone = state.clone();
    let run_dir_clone = run_dir.clone();
    let lang_clone = language.clone();
    let strict = network_mode == "strict";
    tokio::spawn(async move {
        run_zip_test_job(state_clone, run_id, run_dir_clone, lang_clone, strict).await;
    });

    HttpResponse::Ok().json(json!({
        "id": run_id.to_string(),
        "status": "queued",
        "label": label,
        "language": language,
        "network_mode": network_mode,
    }))
}

pub async fn get_module_test_run(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
) -> impl Responder {
    let secret = match jwt_secret() {
        Ok(v) => v,
        Err(e) => return e,
    };
    let uid = match get_user_id_from_token(&req, &secret) {
        Some(v) => v,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };
    let run_id = path.into_inner();
    let row = sqlx::query_as::<
        _,
        (
            Uuid,
            String,
            Option<String>,
            Option<String>,
            String,
            Option<serde_json::Value>,
            chrono::DateTime<chrono::Utc>,
        ),
    >(
        r#"SELECT id, label, git_url, demo_mode, status, summary, created_at
           FROM module_test_runs WHERE id = $1 AND user_id = $2"#,
    )
    .bind(run_id)
    .bind(uid)
    .fetch_optional(&state.pool)
    .await;

    match row {
        Ok(Some((id, label, git_url, demo_mode, status, summary, created_at))) => {
            let mut out = serde_json::to_value(ModuleTestRunOut {
                id: id.to_string(),
                label,
                git_url,
                demo_mode,
                status,
                summary,
                created_at,
            })
            .unwrap_or_else(|_| json!({}));
            if let Some(status_s) = out.get("status").and_then(|v| v.as_str()) {
                if status_s == "queued" || status_s == "running" {
                    let stage = out
                        .get("summary")
                        .and_then(|v| v.get("stage"))
                        .and_then(|v| v.as_str())
                        .unwrap_or("running")
                        .to_string();
                    let percent = out
                        .get("summary")
                        .and_then(|v| v.get("percent"))
                        .and_then(|v| v.as_i64())
                        .unwrap_or(10) as i32;
                    let language = out
                        .get("summary")
                        .and_then(|v| v.get("language"))
                        .and_then(|v| v.as_str())
                        .unwrap_or("python");
                    let archive_size_bytes = out
                        .get("summary")
                        .and_then(|v| v.get("archive_size_bytes"))
                        .and_then(|v| v.as_i64());
                    let eta = match historical_eta_seconds(&state, uid, language, archive_size_bytes, percent).await {
                        Some(v) => v,
                        None => eta_from_stage(&stage, percent, created_at),
                    };
                    if let Some(obj) = out.as_object_mut() {
                        obj.insert("stage".into(), json!(stage));
                        obj.insert("percent".into(), json!(percent));
                        obj.insert("eta_seconds".into(), json!(eta));
                        obj.insert("eta_source".into(), json!("history+size"));
                    }
                }
            }
            HttpResponse::Ok().json(out)
        }
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "Run not found".into(),
        }),
        Err(e) => HttpResponse::InternalServerError().json(ErrorResponse {
            error: format!("Database error: {}", e),
        }),
    }
}

pub async fn get_module_test_logs(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<Uuid>,
    q: web::Query<LogQuery>,
) -> impl Responder {
    let secret = match jwt_secret() {
        Ok(v) => v,
        Err(e) => return e,
    };
    let uid = match get_user_id_from_token(&req, &secret) {
        Some(v) => v,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };
    let run_id = path.into_inner();
    let own = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM module_test_runs WHERE id = $1 AND user_id = $2)",
    )
    .bind(run_id)
    .bind(uid)
    .fetch_one(&state.pool)
    .await
    .unwrap_or(false);
    if !own {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "Run not found".into(),
        });
    }
    let log_path = PathBuf::from(upload_root())
        .join(run_id.to_string())
        .join("runner.log");
    let bytes = match fs::read(&log_path).await {
        Ok(v) => v,
        Err(_) => {
            return HttpResponse::Ok().json(json!({
                "run_id": run_id.to_string(),
                "logs": "",
            }))
        }
    };
    let max_bytes = q.max_bytes.unwrap_or(256 * 1024).min(2 * 1024 * 1024);
    let slice = if bytes.len() > max_bytes {
        &bytes[bytes.len() - max_bytes..]
    } else {
        &bytes[..]
    };
    HttpResponse::Ok().json(json!({
        "run_id": run_id.to_string(),
        "logs": String::from_utf8_lossy(slice),
        "truncated": bytes.len() > max_bytes,
    }))
}

pub async fn compare_module_test_runs(
    state: web::Data<AppState>,
    req: HttpRequest,
    q: web::Query<CompareQuery>,
) -> impl Responder {
    let secret = match jwt_secret() {
        Ok(v) => v,
        Err(e) => return e,
    };
    let uid = match get_user_id_from_token(&req, &secret) {
        Some(v) => v,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let mut rows: Vec<(Uuid, String, String, Option<serde_json::Value>, chrono::DateTime<chrono::Utc>)> = Vec::new();
    if let Some(ids_csv) = &q.ids {
        let ids: Vec<Uuid> = ids_csv
            .split(',')
            .filter_map(|s| Uuid::parse_str(s.trim()).ok())
            .take(50)
            .collect();
        for rid in ids {
            if let Ok(Some(r)) = sqlx::query_as::<
                _,
                (Uuid, String, String, Option<serde_json::Value>, chrono::DateTime<chrono::Utc>),
            >(
                "SELECT id,label,status,summary,created_at FROM module_test_runs WHERE id=$1 AND user_id=$2",
            )
            .bind(rid)
            .bind(uid)
            .fetch_optional(&state.pool)
            .await
            {
                rows.push(r);
            }
        }
    } else {
        let limit = q.limit.unwrap_or(10).min(100) as i64;
        rows = sqlx::query_as::<
            _,
            (Uuid, String, String, Option<serde_json::Value>, chrono::DateTime<chrono::Utc>),
        >(
            "SELECT id,label,status,summary,created_at FROM module_test_runs WHERE user_id=$1 ORDER BY created_at DESC LIMIT $2",
        )
        .bind(uid)
        .bind(limit)
        .fetch_all(&state.pool)
        .await
        .unwrap_or_default();
    }

    let mut table: Vec<serde_json::Value> = rows
        .into_iter()
        .map(|(id, label, status, summary, created_at)| {
            let s = summary.unwrap_or_else(|| json!({}));
            json!({
                "id": id.to_string(),
                "label": label,
                "status": status,
                "created_at": created_at,
                "language": s.get("language").cloned().unwrap_or(json!(null)),
                "strict_offline": s.get("strict_offline").cloned().unwrap_or(json!(null)),
                "stage": s.get("stage").cloned().unwrap_or(json!(null)),
                "percent": s.get("percent").cloned().unwrap_or(json!(null)),
                "vulnerabilities_total": s.pointer("/dependency_security/vulnerabilities_total").cloned().unwrap_or(json!(null)),
                "ruff_exit_code": s.pointer("/quality_tools/ruff_exit_code").cloned().unwrap_or(json!(null)),
                "mypy_exit_code": s.pointer("/quality_tools/mypy_exit_code").cloned().unwrap_or(json!(null)),
                "bandit_exit_code": s.pointer("/quality_tools/bandit_exit_code").cloned().unwrap_or(json!(null)),
                "clippy_exit_code": s.pointer("/quality_tools/clippy_exit_code").cloned().unwrap_or(json!(null)),
                "tests_exit_code": s.pointer("/quality_tools/tests_exit_code").cloned().unwrap_or(json!(null)),
                "exit_code": s.get("exit_code").cloned().unwrap_or(json!(null)),
                "elapsed_seconds": s.get("elapsed_seconds").cloned().unwrap_or(json!(null)),
            })
        })
        .collect();
    let sort_by = q.sort_by.clone().unwrap_or_else(|| "created_at".to_string());
    let sort_desc = q
        .sort_dir
        .as_deref()
        .unwrap_or("desc")
        .eq_ignore_ascii_case("desc");
    table.sort_by(|a, b| {
        let ord = match sort_by.as_str() {
            "label" => a["label"].as_str().cmp(&b["label"].as_str()),
            "status" => a["status"].as_str().cmp(&b["status"].as_str()),
            "language" => a["language"].as_str().cmp(&b["language"].as_str()),
            "vulnerabilities_total" => a["vulnerabilities_total"]
                .as_i64()
                .cmp(&b["vulnerabilities_total"].as_i64()),
            "tests_exit_code" => a["tests_exit_code"].as_i64().cmp(&b["tests_exit_code"].as_i64()),
            "elapsed_seconds" => a["elapsed_seconds"].as_i64().cmp(&b["elapsed_seconds"].as_i64()),
            _ => a["created_at"].as_str().cmp(&b["created_at"].as_str()),
        };
        if sort_desc { ord.reverse() } else { ord }
    });
    HttpResponse::Ok().json(json!({ "rows": table }))
}

pub async fn get_module_test_artifact(
    state: web::Data<AppState>,
    req: HttpRequest,
    path: web::Path<(Uuid, String)>,
) -> impl Responder {
    let secret = match jwt_secret() {
        Ok(v) => v,
        Err(e) => return e,
    };
    let uid = match get_user_id_from_token(&req, &secret) {
        Some(v) => v,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };
    let (run_id, name) = path.into_inner();
    let own = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM module_test_runs WHERE id = $1 AND user_id = $2)",
    )
    .bind(run_id)
    .bind(uid)
    .fetch_one(&state.pool)
    .await
    .unwrap_or(false);
    if !own {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "Run not found".into(),
        });
    }
    let allowed = [
        "summary.json",
        "quality.json",
        "deps_security.json",
        "diploma_report.json",
        "diploma_report.pdf",
    ];
    if !allowed.contains(&name.as_str()) {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Unsupported artifact name".into(),
        });
    }
    let artifact_path = PathBuf::from(upload_root())
        .join(run_id.to_string())
        .join("out")
        .join(&name);
    let bytes = match fs::read(&artifact_path).await {
        Ok(v) => v,
        Err(_) => {
            return HttpResponse::NotFound().json(ErrorResponse {
                error: "Artifact not found".into(),
            })
        }
    };
    let content_type = if name.ends_with(".pdf") {
        "application/pdf"
    } else {
        "application/json"
    };
    HttpResponse::Ok()
        .insert_header(("Content-Type", content_type))
        .insert_header(("Content-Disposition", format!("attachment; filename=\"{}\"", name)))
        .body(bytes)
}
