from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time

from fastapi import HTTPException

from app.config import get_settings

_DEFAULT_TTL = 60 * 60 * 12

def _b64e(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")

def _b64d(raw: str) -> bytes:
    padded = raw + "=" * ((4 - len(raw) % 4) % 4)
    return base64.urlsafe_b64decode(padded.encode("ascii"))

def _secret() -> bytes:
    s = get_settings()
    seed = (s.mattermost_webhook_secret or "").strip()
    if not seed:
        raise ValueError("MATTERMOST_WEBHOOK_SECRET не задан")
    return seed.encode("utf-8")

def issue_chat_token(username: str, *, role: str, ttl_sec: int = _DEFAULT_TTL) -> tuple[str, int]:
    exp = int(time.time()) + ttl_sec
    payload = {"u": username, "r": role, "exp": exp}
    body = _b64e(json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode("utf-8"))
    sig = _b64e(hmac.new(_secret(), body.encode("ascii"), hashlib.sha256).digest())
    return f"{body}.{sig}", exp

def verify_chat_token(token: str) -> dict:
    if "." not in token:
        raise HTTPException(status_code=401, detail="Неверный токен")
    body, sig = token.split(".", 1)
    expected = _b64e(hmac.new(_secret(), body.encode("ascii"), hashlib.sha256).digest())
    if not hmac.compare_digest(sig, expected):
        raise HTTPException(status_code=401, detail="Подпись токена невалидна")
    try:
        payload = json.loads(_b64d(body))
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Токен повреждён") from exc
    exp = int(payload.get("exp", 0))
    if exp <= int(time.time()):
        raise HTTPException(status_code=401, detail="Токен истёк")
    if not payload.get("u"):
        raise HTTPException(status_code=401, detail="Токен без пользователя")
    return payload
