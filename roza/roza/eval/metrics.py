"""Запуск eval-задач и сохранение метрик для дашборда студии."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml

from roza.assistant import build_system_content
from roza.config import Settings
from roza.llm import chat_completion


def load_tasks(path: Path) -> list[dict[str, Any]]:
    with path.open(encoding="utf-8") as f:
        raw = yaml.safe_load(f) or {}
    tasks = raw.get("tasks") or []
    if not isinstance(tasks, list):
        return []
    return [t for t in tasks if isinstance(t, dict)]


def score_response(text: str, must_contain: list[str]) -> tuple[bool, list[str]]:
    lower = text.lower()
    missing: list[str] = []
    for frag in must_contain:
        if frag.lower() not in lower:
            missing.append(frag)
    return (len(missing) == 0, missing)


def evaluate_all(settings: Settings, tasks_path: Path) -> dict[str, Any]:
    tasks = load_tasks(tasks_path)
    if not tasks:
        return {"error": "no_tasks", "passed": 0, "total": 0, "tasks": []}

    system = build_system_content(settings)
    messages: list[dict[str, str]] = [{"role": "system", "content": system}]
    task_results: list[dict[str, Any]] = []
    passed = 0

    for t in tasks:
        tid = str(t.get("id", "?"))
        prompt = str(t.get("prompt") or "").strip()
        must = t.get("must_contain") or []
        if not isinstance(must, list):
            must = []
        must_s = [str(x) for x in must]

        messages.append({"role": "user", "content": prompt})
        err: str | None = None
        reply = ""
        try:
            reply = chat_completion(settings, messages, stream=False)
        except Exception as e:
            err = str(e)
            messages.pop()
            task_results.append(
                {"id": tid, "ok": False, "missing": [], "error": err},
            )
            continue

        messages.append({"role": "assistant", "content": reply})
        ok, missing = score_response(reply, must_s)
        if ok:
            passed += 1
        task_results.append({"id": tid, "ok": ok, "missing": missing, "error": None})

    total = len(tasks)
    return {
        "ts": datetime.now(timezone.utc).isoformat(),
        "passed": passed,
        "total": total,
        "percent": round(100.0 * passed / total, 1) if total else 0.0,
        "tasks": task_results,
    }


def save_metrics(settings: Settings, payload: dict[str, Any]) -> Path:
    out = settings.config_dir / "data" / "metrics_eval.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return out
