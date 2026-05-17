from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from roza.config import Settings


def write_job_status(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def read_job_status(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {"state": "idle", "message": ""}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {"state": "idle", "message": "не удалось прочитать статус"}


def train_data_dir(settings: Settings) -> Path:
    p = settings.config_dir / "data" / "train"
    p.mkdir(parents=True, exist_ok=True)
    return p


def status_path(settings: Settings) -> Path:
    return train_data_dir(settings) / "status.json"


def log_path(settings: Settings) -> Path:
    return train_data_dir(settings) / "train.log"


def read_status(settings: Settings) -> dict[str, Any]:
    return read_job_status(status_path(settings))


def write_status(settings: Settings, data: dict[str, Any]) -> None:
    write_job_status(status_path(settings), data)


def tail_log(settings: Settings, n: int = 100) -> str:
    p = log_path(settings)
    if not p.is_file():
        return ""
    lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
    return "\n".join(lines[-n:])
