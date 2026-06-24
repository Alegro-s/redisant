from __future__ import annotations

import base64
import hashlib
import json
import os
from dataclasses import dataclass
from functools import lru_cache

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

_PROFILE_VERSION = 1

@dataclass(frozen=True)
class InferenceEndpoints:
    gateway_base: str
    gateway_token: str
    gateway_model: str
    gateway_timeout: int
    gateway_min_risk: float
    stt_base: str
    stt_token: str
    stt_timeout: int
    voice_base: str
    voice_token: str
    voice_timeout: int
    core_base: str
    core_timeout: int

def _derive_key(seed: str) -> bytes:
    material = hashlib.sha256(f"nt-inf-v1:{seed}".encode("utf-8")).digest()
    return material

def seal_profile(payload: dict, seed: str) -> str:
    body = json.dumps({"v": _PROFILE_VERSION, "d": payload}, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    nonce = os.urandom(12)
    ct = AESGCM(_derive_key(seed)).encrypt(nonce, body, None)
    return base64.urlsafe_b64encode(nonce + ct).decode("ascii")

def open_profile(blob: str, seed: str) -> dict:
    raw = base64.urlsafe_b64decode(blob.encode("ascii"))
    if len(raw) < 13:
        raise ValueError("invalid profile blob")
    nonce, ct = raw[:12], raw[12:]
    body = AESGCM(_derive_key(seed)).decrypt(nonce, ct, None)
    data = json.loads(body.decode("utf-8"))
    if data.get("v") != _PROFILE_VERSION:
        raise ValueError("unsupported profile version")
    inner = data.get("d")
    if not isinstance(inner, dict):
        raise ValueError("invalid profile payload")
    return inner

def _seed() -> str:
    from app.config import get_settings

    s = get_settings()
    primary = (s.secure_config_seed or "").strip()
    if primary:
        return primary
    fallback = (s.admin_api_key or "").strip()
    if fallback:
        return fallback
    return (s.mattermost_webhook_secret or "").strip()

@lru_cache
def get_inference_endpoints() -> InferenceEndpoints:
    from app.config import get_settings

    s = get_settings()
    blob = (s.inference_profile or "").strip()
    if blob:
        try:
            p = open_profile(blob, _seed())
        except Exception:
            p = {}
    else:
        p = {}

    def pick(key: str, legacy: str, default: str = "") -> str:
        v = p.get(key)
        if v is not None and str(v).strip():
            return str(v).strip()
        leg = getattr(s, legacy, "") if legacy else ""
        return (leg or default).strip()

    return InferenceEndpoints(
        gateway_base=pick("gw", "lm_studio_url"),
        gateway_token=pick("gw_t", "lm_studio_api_token"),
        gateway_model=pick("gw_m", "lm_studio_model") or "local-model",
        gateway_timeout=int(p.get("gw_to") or s.lm_studio_timeout or 45),
        gateway_min_risk=float(p.get("gw_risk") or s.lm_studio_min_risk or 0.4),
        stt_base=pick("stt", "whisper_url"),
        stt_token=pick("stt_t", "whisper_api_token"),
        stt_timeout=int(p.get("stt_to") or s.whisper_timeout or 60),
        voice_base=pick("voice", "voice_analyze_url"),
        voice_token=pick("voice_t", "voice_analyze_token"),
        voice_timeout=int(p.get("voice_to") or s.voice_analyze_timeout or 45),
        core_base=pick("core", "ai_core_url"),
        core_timeout=int(p.get("core_to") or s.ai_core_timeout or 30),
    )
