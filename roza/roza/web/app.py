from __future__ import annotations

import asyncio
import functools
import json
import os
import re
import subprocess
import sys
import threading
from collections import OrderedDict
from datetime import datetime
from pathlib import Path
from typing import Any

import httpx
from fastapi import (
    FastAPI,
    File,
    Header,
    HTTPException,
    Query,
    UploadFile,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.responses import FileResponse, JSONResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from starlette.responses import Response
from pydantic import BaseModel, Field

from roza.agent import AgentSession
from roza.assistant import RozaSession
from roza.config import load_settings
from roza.eval.metrics import evaluate_all, save_metrics
from roza.llm_usage import clear_last_llm_usage, take_last_llm_usage
from roza.studio_util import (
    datasets_dir,
    export_learn_to_sharegpt_jsonl,
    load_skills_dashboard,
    merge_sharegpt_files,
    resolve_dataset_file,
)
from roza.train.deps_check import training_imports_ok
from roza.auth_platform import consume_roza_tokens, require_roza_user
from roza.train.job import log_path, read_status, status_path, tail_log, train_data_dir, write_status

STATIC_DIR = Path(__file__).resolve().parent / "static"


class TtsRequest(BaseModel):
    text: str = Field("", max_length=12000)


class MergeExportBody(BaseModel):
    files: list[str] = Field(default_factory=list)
    dest: str = Field("merged_sharegpt.jsonl", max_length=200)


class TrainStartBody(BaseModel):
    base_model: str = Field(..., max_length=500)
    dataset_file: str = Field(..., max_length=260)
    run_name: str = Field("", max_length=120)
    epochs: float = Field(1.0, ge=0.1, le=100)
    learning_rate: float = Field(2e-4, gt=0, le=1e-1)
    lora_r: int = Field(8, ge=4, le=256)
    lora_alpha: int = Field(16, ge=4, le=512)
    max_seq_length: int = Field(1024, ge=128, le=8192)
    per_device_train_batch_size: int = Field(1, ge=1, le=32)
    gradient_accumulation_steps: int = Field(8, ge=1, le=128)
    use_4bit: bool = False


class ChatAttachment(BaseModel):
    """Текстовые вложения к сообщению (Companion / клиенты)."""

    filename: str = Field(..., max_length=512)
    content: str = Field(..., max_length=1_000_000)


class HttpChatBody(BaseModel):
    text: str = Field(..., max_length=500_000)
    agent: bool = False
    session_id: str = Field("default", max_length=128)
    context_key: str = Field("", max_length=128)
    attachments: list[ChatAttachment] = Field(default_factory=list)


class LlmPresetBody(BaseModel):
    """light | strong — из hf_local.preset_* в config; default — как в YAML model_id."""

    preset: str = Field("default", max_length=32)


class LearningEnabledBody(BaseModel):
    enabled: bool


class IntegrationContextBody(BaseModel):
    context_key: str = Field(..., max_length=128)
    markdown: str = Field(..., max_length=2_000_000)


class CompanionEvent(BaseModel):
    id: str = Field(..., max_length=64)
    title: str = Field(..., max_length=500)
    start: str = Field(..., max_length=40)
    end: str = Field("", max_length=40)
    notes: str = Field("", max_length=8000)


class CompanionEventsBody(BaseModel):
    events: list[CompanionEvent] = Field(default_factory=list)


_INTEGRATION_LOCK = threading.Lock()
_integration_chunks: dict[str, str] = {}

_HTTP_SESSION_LOCK = threading.Lock()
_http_sessions: "OrderedDict[str, tuple[RozaSession, AgentSession]]" = OrderedDict()
_HTTP_SESSION_CAP = 200


def _integration_token_ok(authorization: str | None) -> bool:
    expected = (os.environ.get("ROZA_INTEGRATION_TOKEN") or "").strip()
    if not expected:
        return True
    if not authorization or not authorization.startswith("Bearer "):
        return False
    return authorization[7:].strip() == expected


def _pop_integration_prefix(context_key: str) -> str:
    ck = context_key.strip()
    if not ck:
        return ""
    with _INTEGRATION_LOCK:
        return _integration_chunks.pop(ck, "")


def _get_http_session_pair(session_id: str) -> tuple[RozaSession, AgentSession]:
    sid = session_id.strip() or "default"
    settings = load_settings()
    with _HTTP_SESSION_LOCK:
        if sid in _http_sessions:
            pair = _http_sessions.pop(sid)
            _http_sessions[sid] = pair
            return pair
        while len(_http_sessions) >= _HTTP_SESSION_CAP:
            _http_sessions.popitem(last=False)
        pair = (RozaSession(settings), AgentSession(settings))
        _http_sessions[sid] = pair
        return pair


def _companion_events_file() -> Path:
    s = load_settings()
    d = s.config_dir / "companion"
    d.mkdir(parents=True, exist_ok=True)
    return d / "events.json"


def _apply_integration_prefix(context_key: str, text: str) -> str:
    pre = _pop_integration_prefix(context_key)
    if not pre:
        return text
    return (
        "Контекст от внешнего приложения (метрики, данные, выгрузки):\n"
        f"{pre}\n\n---\n\n{text}"
    )


def _merge_attachments_into_prompt(text: str, attachments: list[Any]) -> str:
    if not attachments:
        return text
    parts: list[str] = []
    for i, att in enumerate(attachments[:32]):
        if isinstance(att, dict):
            fn = (str(att.get("filename") or f"file{i + 1}")).strip() or f"file{i + 1}"
            c = (str(att.get("content") or "")).strip()
        elif hasattr(att, "filename") and hasattr(att, "content"):
            fn = (str(getattr(att, "filename", "") or f"file{i + 1}")).strip() or f"file{i + 1}"
            c = (str(getattr(att, "content", "") or "")).strip()
        else:
            continue
        if not c:
            continue
        if len(c) > 900_000:
            c = c[:900_000] + "\n…[обрезано]"
        parts.append(f"### Вложение: {fn}\n```\n{c}\n```")
    if not parts:
        return text
    return "\n\n".join(parts) + "\n\n---\n**Запрос пользователя:**\n" + text


_MAX_UPLOAD = 52 * 1024 * 1024
_RUN_NAME_SAFE = re.compile(r"^[\w.\-]{1,120}$")


def _train_process_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    if sys.platform == "win32":
        import ctypes

        PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        h = ctypes.windll.kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
        if h:
            ctypes.windll.kernel32.CloseHandle(h)
            return True
        return False
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def create_app() -> FastAPI:
    app = FastAPI(title="Roza", docs_url=None, redoc_url=None)

    try:
        _boot = load_settings()
        if _boot.web_cors_origins:
            from fastapi.middleware.cors import CORSMiddleware

            app.add_middleware(
                CORSMiddleware,
                allow_origins=list(_boot.web_cors_origins),
                allow_credentials=True,
                allow_methods=["*"],
                allow_headers=["*"],
            )
    except FileNotFoundError:
        pass

    @app.get("/")
    async def index() -> FileResponse:
        return FileResponse(STATIC_DIR / "index.html")

    app.mount(
        "/static",
        StaticFiles(directory=str(STATIC_DIR)),
        name="static",
    )

    def _ollama_ping(base: str) -> tuple[str, int | None]:
        try:
            r = httpx.get(f"{base.rstrip('/')}/api/tags", timeout=3.0)
            return ("ok" if r.status_code == 200 else "error", r.status_code)
        except Exception:
            return ("down", None)

    def _openai_ping(base: str, key: str) -> tuple[str, int | None]:
        try:
            h = {"Authorization": f"Bearer {key}"} if key else {}
            r = httpx.get(f"{base.rstrip('/')}/models", headers=h, timeout=4.0)
            return ("ok" if r.status_code == 200 else "error", r.status_code)
        except Exception:
            return ("down", None)

    @app.get("/api/health")
    async def health() -> dict:
        s = load_settings()
        b = s.llm_backend
        if b == "ollama":
            status, code = await asyncio.to_thread(_ollama_ping, s.ollama_base_url)
            return {
                "llm_backend": "ollama",
                "ollama": status,
                "status_code": code,
                "ok": status == "ok",
            }
        if b == "llama_cpp":
            p = s.llama_cpp_model_path
            ok = p is not None and p.is_file()
            return {
                "llm_backend": "llama_cpp",
                "ollama": None,
                "ok": ok,
                "model_path": str(p) if p else None,
            }
        if b == "openai_compatible":
            st, code = await asyncio.to_thread(
                _openai_ping,
                s.openai_base_url,
                s.openai_api_key,
            )
            return {
                "llm_backend": "openai_compatible",
                "ollama": None,
                "openai": st,
                "status_code": code,
                "ok": st == "ok",
            }
        if b == "hf_local":
            from roza.hf_local_llm import effective_hf_model_id, hf_local_deps_available

            deps_ok = hf_local_deps_available()
            mid = effective_hf_model_id(s)
            return {
                "llm_backend": "hf_local",
                "ollama": None,
                "ok": deps_ok and bool(mid),
                "model_id": mid or None,
                "preset_light": s.hf_local_preset_light,
                "preset_strong": s.hf_local_preset_strong,
                "hint": (
                    None
                    if deps_ok
                    else 'Установите: pip install -e ".[hf]" (или ".[train]")'
                ),
            }
        return {"llm_backend": b, "ok": False}

    @app.get("/api/llm/runtime")
    async def llm_runtime() -> dict[str, Any]:
        s = load_settings()
        from roza.hf_local_llm import effective_hf_model_id

        return {
            "llm_backend": s.llm_backend,
            "hf_from_config_model_id": s.hf_local_model_id,
            "hf_effective_model_id": effective_hf_model_id(s)
            if s.llm_backend == "hf_local"
            else None,
            "hf_preset_light": s.hf_local_preset_light,
            "hf_preset_strong": s.hf_local_preset_strong,
            "api": {
                "set_preset": "POST /api/llm/preset  body: {\"preset\":\"light\"|\"strong\"|\"default\"}",
                "datasets_upload": "POST /api/studio/datasets/upload  multipart file",
            },
        }

    @app.post("/api/llm/preset")
    async def llm_preset(body: LlmPresetBody) -> dict[str, Any]:
        s = load_settings()
        if s.llm_backend != "hf_local":
            raise HTTPException(
                status_code=400,
                detail="Переключение пресетов только при llm.backend: hf_local",
            )
        from roza.hf_local_llm import effective_hf_model_id, set_hf_local_model_id_override

        p = (body.preset or "default").strip().lower()
        if p == "light":
            set_hf_local_model_id_override(s.hf_local_preset_light)
        elif p == "strong":
            set_hf_local_model_id_override(s.hf_local_preset_strong)
        elif p in ("default", "config", "reset"):
            set_hf_local_model_id_override(None)
        else:
            raise HTTPException(
                status_code=400,
                detail="preset: light | strong | default",
            )
        return {"ok": True, "model_id": effective_hf_model_id(s)}

    @app.get("/api/learning/stats")
    async def learning_stats() -> dict[str, Any]:
        s = load_settings()
        from roza.runtime_prefs import effective_learning_enabled

        path = s.learning_log_path
        n_lines = 0
        size = 0
        if path.is_file():
            size = path.stat().st_size
            try:
                with path.open(encoding="utf-8") as f:
                    n_lines = sum(1 for _ in f)
            except OSError:
                n_lines = -1
        return {
            "enabled": effective_learning_enabled(s),
            "persisted_in_config": s.learning_enabled,
            "log_path": str(path),
            "lines": n_lines,
            "bytes": size,
        }

    @app.get("/api/learning/enabled")
    async def learning_enabled_get() -> dict[str, Any]:
        s = load_settings()
        from roza.runtime_prefs import effective_learning_enabled, learning_override_is_set

        return {
            "enabled": effective_learning_enabled(s),
            "persisted_in_config": s.learning_enabled,
            "session_override": learning_override_is_set(),
        }

    @app.post("/api/learning/enabled")
    async def learning_enabled_post(body: LearningEnabledBody) -> dict[str, Any]:
        from roza.runtime_prefs import effective_learning_enabled, set_learning_enabled_override

        set_learning_enabled_override(bool(body.enabled))
        s = load_settings()
        return {"ok": True, "enabled": effective_learning_enabled(s)}

    @app.get("/studio")
    async def studio_page() -> FileResponse:
        return FileResponse(STATIC_DIR / "studio.html")

    @app.get("/api/studio/skills")
    async def studio_skills() -> dict:
        return load_skills_dashboard(load_settings())

    @app.post("/api/studio/benchmark")
    async def studio_benchmark() -> dict:
        s = load_settings()
        tasks_path = (s.config_dir / "eval" / "code_tasks.yaml").resolve()
        if not tasks_path.is_file():
            raise HTTPException(status_code=404, detail="eval/code_tasks.yaml не найден")

        def _run() -> dict[str, Any]:
            res = evaluate_all(s, tasks_path)
            if res.get("error") == "no_tasks":
                return {"ok": False, "error": "Нет задач в YAML"}
            save_metrics(s, res)
            return {"ok": True, "result": res}

        out = await asyncio.to_thread(_run)
        if not out.get("ok"):
            raise HTTPException(status_code=400, detail=out.get("error", "benchmark"))
        return out

    @app.get("/api/studio/datasets")
    async def studio_datasets_list() -> dict:
        s = load_settings()
        root = datasets_dir(s)
        files = []
        for p in sorted(root.iterdir()):
            if p.is_file() and not p.name.startswith("."):
                files.append(
                    {
                        "name": p.name,
                        "size": p.stat().st_size,
                    }
                )
        return {"dir": str(root), "files": files}

    @app.post("/api/studio/datasets/upload")
    async def studio_datasets_upload(file: UploadFile = File(...)) -> dict:
        s = load_settings()
        root = datasets_dir(s)
        name = (file.filename or "").strip().replace("\\", "/").split("/")[-1]
        if not name or ".." in name or "/" in name:
            raise HTTPException(status_code=400, detail="Некорректное имя файла")
        low = name.lower()
        if not low.endswith((".jsonl", ".json", ".txt", ".yaml", ".yml")):
            raise HTTPException(
                status_code=400,
                detail="Допустимы: .jsonl .json .txt .yaml .yml",
            )
        raw = await file.read()
        if len(raw) > _MAX_UPLOAD:
            raise HTTPException(status_code=413, detail="Файл слишком большой (лимит 52 МБ)")
        dest = root / name
        dest.write_bytes(raw)
        return {"ok": True, "path": str(dest), "name": name}

    @app.delete("/api/studio/datasets/{name}")
    async def studio_datasets_delete(name: str) -> dict:
        s = load_settings()
        root = datasets_dir(s)
        if ".." in name or "/" in name or not name:
            raise HTTPException(status_code=400, detail="Некорректное имя")
        p = (root / name).resolve()
        if not str(p).startswith(str(root.resolve())) or not p.is_file():
            raise HTTPException(status_code=404, detail="Не найдено")
        p.unlink()
        return {"ok": True}

    @app.post("/api/studio/export/learn")
    async def studio_export_learn(
        dest: str = Query("roza_learn_sharegpt.jsonl", max_length=200),
    ) -> dict:
        s = load_settings()
        if not dest.endswith(".jsonl"):
            dest = dest + ".jsonl"
        try:
            path = export_learn_to_sharegpt_jsonl(s, dest)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e)) from e
        return {"ok": True, "path": str(path), "hint": "Формат ShareGPT JSONL для LlamaFactory"}

    @app.post("/api/studio/export/merge")
    async def studio_export_merge(body: MergeExportBody) -> dict:
        s = load_settings()
        dest = body.dest.strip() or "merged_sharegpt.jsonl"
        if not dest.endswith(".jsonl"):
            dest += ".jsonl"
        try:
            path = merge_sharegpt_files(s, body.files, dest)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e)) from e
        return {"ok": True, "path": str(path)}

    @app.get("/api/studio/train/deps")
    async def studio_train_deps() -> dict:
        ok, missing = training_imports_ok()
        return {"ok": ok, "missing": missing, "hint": 'pip install -e ".[train]"'}

    @app.get("/api/studio/train/status")
    async def studio_train_status() -> dict:
        s = load_settings()
        st = read_status(s)
        if st.get("state") == "running":
            pid = int(st.get("pid") or 0)
            if pid and not _train_process_alive(pid):
                st = {
                    **st,
                    "state": "error",
                    "message": "Процесс обучения завершился (см. train.log).",
                    "pid": 0,
                }
                write_status(s, st)
        return st

    @app.get("/api/studio/train/log")
    async def studio_train_log(tail: int = Query(120, ge=10, le=2000)) -> dict:
        s = load_settings()
        return {"text": tail_log(s, tail)}

    @app.post("/api/studio/train/start")
    async def studio_train_start(body: TrainStartBody) -> dict:
        s = load_settings()
        ok_deps, missing = training_imports_ok()
        if not ok_deps:
            raise HTTPException(
                status_code=503,
                detail=f"Нет пакетов: {', '.join(missing)}. Установите: pip install -e \".[train]\"",
            )

        st = read_status(s)
        if st.get("state") == "running":
            pid = int(st.get("pid") or 0)
            if pid and _train_process_alive(pid):
                raise HTTPException(
                    status_code=409,
                    detail="Уже идёт обучение. Дождитесь завершения или проверьте статус.",
                )

        try:
            ds_path = resolve_dataset_file(s, body.dataset_file)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e)) from e

        run_name = (body.run_name or "").strip()
        if not run_name:
            run_name = f"lora_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        if not _RUN_NAME_SAFE.match(run_name):
            raise HTTPException(status_code=400, detail="Некорректное имя run_name")

        tdir = train_data_dir(s)
        output_dir = (tdir / "runs" / run_name).resolve()
        if not str(output_dir).startswith(str(tdir.resolve())):
            raise HTTPException(status_code=400, detail="Некорректный путь выхода")
        output_dir.mkdir(parents=True, exist_ok=True)

        job = {
            "base_model": body.base_model.strip(),
            "dataset_path": str(ds_path),
            "output_dir": str(output_dir),
            "status_path": str(status_path(s)),
            "log_path": str(log_path(s)),
            "run_name": run_name,
            "epochs": body.epochs,
            "learning_rate": body.learning_rate,
            "lora_r": body.lora_r,
            "lora_alpha": body.lora_alpha,
            "max_seq_length": body.max_seq_length,
            "per_device_train_batch_size": body.per_device_train_batch_size,
            "gradient_accumulation_steps": body.gradient_accumulation_steps,
            "use_4bit": body.use_4bit,
        }
        job_path = tdir / "job_last.json"
        job_path.write_text(json.dumps(job, ensure_ascii=False, indent=2), encoding="utf-8")

        lp = log_path(s)
        with lp.open("a", encoding="utf-8") as lf:
            lf.write(f"\n--- train start {datetime.now().isoformat()} run={run_name} ---\n")

        write_status(
            s,
            {
                "state": "queued",
                "message": "Запуск процесса…",
                "started": datetime.now().isoformat(),
                "output_dir": str(output_dir),
                "pid": 0,
                "run_name": run_name,
            },
        )

        cmd = [sys.executable, "-m", "roza.train", "--job", str(job_path.resolve())]
        cwd = str(s.config_dir.resolve())
        env = os.environ.copy()
        if os.environ.get("ROZA_CONFIG"):
            env["ROZA_CONFIG"] = os.environ["ROZA_CONFIG"]

        popen_kw: dict[str, Any] = {
            "args": cmd,
            "cwd": cwd,
            "env": env,
            "stdin": subprocess.DEVNULL,
            "stdout": subprocess.DEVNULL,
            "stderr": subprocess.DEVNULL,
        }
        if sys.platform == "win32":
            cf = getattr(subprocess, "CREATE_NO_WINDOW", 0)
            if cf:
                popen_kw["creationflags"] = cf

        try:
            proc = subprocess.Popen(**popen_kw)
        except OSError as e:
            write_status(
                s,
                {
                    "state": "error",
                    "message": str(e),
                    "pid": 0,
                    "output_dir": str(output_dir),
                },
            )
            raise HTTPException(status_code=500, detail=str(e)) from e

        write_status(
            s,
            {
                "state": "running",
                "message": "Обучение запущено",
                "started": datetime.now().isoformat(),
                "output_dir": str(output_dir),
                "pid": proc.pid or 0,
                "run_name": run_name,
            },
        )

        return {
            "ok": True,
            "pid": proc.pid,
            "output_dir": str(output_dir),
            "job": str(job_path),
            "log": str(log_path(s)),
        }

    @app.get("/api/ui-config")
    async def ui_config() -> dict:
        s = load_settings()
        return {
            "tts_provider": s.voice_provider,
            "edge_voice": s.edge_tts_voice,
            "assistant_name": s.assistant_name,
            "voice_require_wake_word": s.voice_require_wake_word,
            "voice_wake_words": s.voice_wake_words,
            "voice_auto_start_listening": s.voice_auto_start_listening,
            "voice_wake_latch_seconds": s.voice_wake_latch_seconds,
            "assistant_think_first": s.assistant_think_first,
            "assistant_swarm_prompt": s.assistant_swarm_prompt,
            "web_cors": bool(s.web_cors_origins),
            "desktop_shell": os.environ.get("ROZA_DESKTOP") == "1",
            "ui_defaults": {
                "agent": True,
                "autoVoice": True,
                "speak": s.voice_provider != "none",
            },
            "learning_log_path": str(s.learning_log_path),
            "learning_persisted_enabled": s.learning_enabled,
            "llm_api": {
                "runtime": "GET /api/llm/runtime",
                "preset": "POST /api/llm/preset  {\"preset\":\"light\"|\"strong\"|\"default\"}",
                "learning_stats": "GET /api/learning/stats",
                "learning_toggle": "POST /api/learning/enabled  {\"enabled\":true}",
            },
        }

    @app.get("/api/workspace")
    async def api_workspace() -> dict[str, Any]:
        s = load_settings()
        roots = [str(p.resolve()) for p in s.workspace_roots]
        return {
            "roots": roots,
            "local_only": True,
            "hint": "Данные с вашего ПК; LLM по умолчанию локально (hf_local / llama_cpp), без облака.",
        }

    @app.get("/api/workspace/list")
    async def api_workspace_list(
        path: str = Query(".", max_length=4096),
    ) -> dict[str, Any]:
        s = load_settings()
        if not s.workspace_roots:
            raise HTTPException(
                status_code=400,
                detail="Задайте workspace.roots в config.yaml",
            )
        from roza.filesafe import list_dir_json

        try:
            entries = list_dir_json(path, s.workspace_roots)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e)) from e
        except NotADirectoryError:
            raise HTTPException(status_code=404, detail="Не каталог") from None
        return {"path": path.strip() or ".", "entries": entries}

    @app.get("/api/workspace/file")
    async def api_workspace_file(
        path: str = Query(..., min_length=1, max_length=4096),
    ) -> dict[str, Any]:
        s = load_settings()
        if not s.workspace_roots:
            raise HTTPException(status_code=400, detail="workspace.roots пуст")
        from roza.filesafe import read_text

        try:
            text = read_text(path, s.workspace_roots, max_chars=100_000)
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e)) from e
        except FileNotFoundError:
            raise HTTPException(status_code=404, detail="Файл не найден") from None
        except OSError as e:
            raise HTTPException(status_code=400, detail=str(e)) from e
        return {"path": path, "text": text}

    @app.post("/api/tts", response_model=None)
    async def tts_audio(body: TtsRequest) -> Response:
        s = load_settings()
        if s.voice_provider != "edge":
            return JSONResponse(
                {"ok": False, "error": "voice.provider не edge"},
                status_code=400,
            )
        text = body.text.strip()
        if not text:
            return JSONResponse({"ok": False, "error": "пустой текст"}, status_code=400)
        try:
            import edge_tts
        except ImportError:
            return JSONResponse(
                {
                    "ok": False,
                    "error": "Установите: pip install edge-tts",
                },
                status_code=503,
            )

        communicate = edge_tts.Communicate(text, s.edge_tts_voice)

        async def audio_iter():
            async for chunk in communicate.stream():
                if chunk["type"] == "audio":
                    yield chunk["data"]

        return StreamingResponse(
            audio_iter(),
            media_type="audio/mpeg",
        )

    @app.post("/api/integration/context")
    async def integration_context(
        body: IntegrationContextBody,
        authorization: str | None = Header(default=None, alias="Authorization"),
    ) -> dict[str, Any]:
        """Внешнее приложение (метрики, BI) кладёт markdown; следующий чат с тем же context_key получит префикс."""
        if not _integration_token_ok(authorization):
            raise HTTPException(
                status_code=401,
                detail="Неверный токен интеграции (переменная ROZA_INTEGRATION_TOKEN, заголовок Authorization: Bearer …)",
            )
        ck = body.context_key.strip()
        if not ck:
            raise HTTPException(status_code=400, detail="context_key пуст")
        md = body.markdown.strip()
        if not md:
            raise HTTPException(status_code=400, detail="markdown пуст")
        with _INTEGRATION_LOCK:
            _integration_chunks[ck] = md[:2_000_000]
        return {"ok": True}

    @app.post("/api/chat")
    async def api_http_chat(
        body: HttpChatBody,
        authorization: str | None = Header(default=None, alias="Authorization"),
    ) -> dict[str, Any]:
        """Синхронный чат для сторонних клиентов (C#, curl). Сессия живёт в памяти сервера по session_id."""
        text_in = body.text.strip()
        if not text_in:
            raise HTTPException(status_code=400, detail="пустой text")
        try:
            await require_roza_user(authorization)
        except PermissionError as e:
            raise HTTPException(status_code=401, detail=str(e)) from e

        text = _apply_integration_prefix(body.context_key, text_in)
        text = _merge_attachments_into_prompt(text, list(body.attachments))
        chat, ag = _get_http_session_pair(body.session_id)
        sess: RozaSession | AgentSession = ag if body.agent else chat
        clear_last_llm_usage()
        try:
            reply = await asyncio.to_thread(
                functools.partial(sess.ask, text, stream=False),
            )
        except Exception as e:
            if sess.history and sess.history[-1].get("role") == "user":
                sess.history.pop()
            raise HTTPException(status_code=500, detail=str(e)) from e
        usage = take_last_llm_usage()
        try:
            await consume_roza_tokens(authorization, text_in, reply or "")
        except PermissionError as e:
            raise HTTPException(status_code=429, detail=str(e)) from e
        return {
            "reply": reply,
            "session_id": body.session_id.strip() or "default",
            "usage": usage,
        }

    @app.get("/api/companion/events")
    async def companion_events_get() -> dict[str, Any]:
        p = _companion_events_file()
        if not p.is_file():
            return {"events": []}
        try:
            raw = json.loads(p.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {"events": []}
        ev = raw.get("events") if isinstance(raw, dict) else None
        if not isinstance(ev, list):
            return {"events": []}
        return {"events": ev}

    @app.put("/api/companion/events")
    async def companion_events_put(body: CompanionEventsBody) -> dict[str, Any]:
        p = _companion_events_file()
        out = [e.model_dump() for e in body.events]
        p.write_text(
            json.dumps({"events": out}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        return {"ok": True, "count": len(out)}

    @app.websocket("/ws/chat")
    async def ws_chat(ws: WebSocket) -> None:
        """Чат по WebSocket: те же сессии, что и у POST /api/chat (ключ session_id)."""
        await ws.accept()
        try:
            while True:
                data = await ws.receive_json()
                t = data.get("type")
                if t == "ping":
                    await ws.send_json({"type": "pong"})
                    continue
                if t == "reset":
                    sid = (data.get("session_id") or "").strip() or "default"
                    chat, agent = _get_http_session_pair(sid)
                    chat.reset()
                    agent.reset()
                    await ws.send_json({"type": "reset_ok"})
                    continue
                if t != "message":
                    continue
                sid = (data.get("session_id") or "").strip() or "default"
                chat, agent = _get_http_session_pair(sid)
                text = (data.get("text") or "").strip()
                if not text:
                    continue
                ck = (data.get("context_key") or "").strip()
                text = _apply_integration_prefix(ck, text)
                raw_atts = data.get("attachments")
                att_rows: list[Any] = []
                if isinstance(raw_atts, list):
                    att_rows = [x for x in raw_atts if isinstance(x, dict)]
                text = _merge_attachments_into_prompt(text, att_rows)
                use_agent = bool(data.get("agent"))
                sess: RozaSession | AgentSession = agent if use_agent else chat
                await ws.send_json({"type": "thinking"})
                clear_last_llm_usage()
                try:
                    reply = await asyncio.to_thread(
                        functools.partial(sess.ask, text, stream=False),
                    )
                except Exception as e:
                    await ws.send_json({"type": "error", "message": str(e)})
                    if sess.history and sess.history[-1].get("role") == "user":
                        sess.history.pop()
                    continue
                usage = take_last_llm_usage()
                await ws.send_json({"type": "reply", "text": reply, "usage": usage})
        except WebSocketDisconnect:
            pass

    return app
