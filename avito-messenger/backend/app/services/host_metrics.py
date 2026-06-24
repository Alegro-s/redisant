from __future__ import annotations

import os
import time

import httpx
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import get_settings

try:
    import psutil
except ImportError:
    psutil = None

def _disk_pct() -> float:
    if not psutil:
        return 0.0
    try:
        return round(psutil.disk_usage("/").percent, 1)
    except OSError:
        return 0.0

def collect_host_load() -> dict:
    if not psutil:
        return {"cpu": 0.0, "ram": 0.0, "gpu": 0.0, "disk": 0.0}
    try:
        cpu = psutil.cpu_percent(interval=0.1)
    except Exception:
        cpu = 0.0
    try:
        ram = psutil.virtual_memory().percent
    except Exception:
        ram = 0.0
    return {
        "cpu": round(float(cpu), 1),
        "ram": round(float(ram), 1),
        "gpu": 0.0,
        "disk": _disk_pct(),
    }

def measure_db_latency_ms(db: Session) -> tuple[bool, int]:
    t0 = time.perf_counter()
    try:
        db.execute(text("SELECT 1"))
        ms = int((time.perf_counter() - t0) * 1000)
        return True, ms
    except Exception:
        return False, int((time.perf_counter() - t0) * 1000)

def measure_http_latency_ms(url: str, timeout: float = 3.0) -> tuple[bool, int | None]:
    try:
        with httpx.Client(timeout=timeout) as client:
            t0 = time.perf_counter()
            res = client.get(url)
            ms = int((time.perf_counter() - t0) * 1000)
            return res.status_code < 500, ms
    except httpx.HTTPError:
        return False, None

def collect_tokens() -> dict:
    if not psutil:
        return {"stylometry": 0, "embeddings": 0, "explain": 0, "speech": 0, "vision": 0}
    proc = psutil.Process(os.getpid())
    mem_mb = int(proc.memory_info().rss / (1024 * 1024))
    return {
        "stylometry": mem_mb,
        "embeddings": int(psutil.cpu_count() or 0),
        "explain": int(proc.num_threads()),
        "speech": 0,
        "vision": 0,
    }
