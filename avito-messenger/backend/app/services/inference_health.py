from __future__ import annotations

import time

import httpx

from app.config import get_settings
from app.services.ai_client import ai_service_online
from app.services.lm_studio_client import lm_studio_configured, lm_studio_status
from app.services.secure_bundle import get_inference_endpoints
from app.services.voice_analyze import voice_analyze_configured

_CACHE: tuple[float, dict] = (0.0, {})

def _whisper_ping() -> dict:
    ep = get_inference_endpoints()
    base = (ep.stt_base or "").strip().rstrip("/")
    if not base:
        return {"configured": False, "online": False, "detail": "не настроен"}
    health = base.replace("/transcribe", "") + "/health" if "/transcribe" in base else f"{base}/health"
    try:
        with httpx.Client(timeout=5) as client:
            res = client.get(health)
        return {"configured": True, "online": res.status_code == 200, "detail": f"HTTP {res.status_code}"}
    except httpx.HTTPError as exc:
        return {"configured": True, "online": False, "detail": str(exc)[:80]}

def inference_nodes_status() -> dict:
    global _CACHE
    now = time.time()
    if now - _CACHE[0] < 30:
        return _CACHE[1]
    lm = lm_studio_status() if lm_studio_configured() else None
    whisper = _whisper_ping()
    ai_online, _ = ai_service_online()
    settings = get_settings()
    core_url = settings.ai_core_url or voice_analyze_configured()
    nodes = {
        "lm_studio": {
            "configured": lm_studio_configured(),
            "online": bool(lm and lm.online),
            "host": getattr(lm, "host", "") if lm else "",
            "detail": getattr(lm, "detail", "") if lm else "не настроен",
        },
        "whisper": whisper,
        "ai_core": {
            "configured": bool(core_url or settings.ai_service_url),
            "online": bool(ai_online or voice_analyze_configured()),
            "detail": "GPU-ПК: embeddings + voice",
        },
    }
    online_count = sum(1 for n in nodes.values() if n.get("online"))
    mode = "full" if online_count >= 2 else "degraded" if online_count == 1 else "minimal"
    out = {"mode": mode, "nodes": nodes, "online_count": online_count}
    _CACHE = (now, out)
    return out
