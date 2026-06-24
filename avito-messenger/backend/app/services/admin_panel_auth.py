from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import time
from pathlib import Path
from typing import Any

from fastapi import Header, HTTPException

from app.config import get_settings

SESSION_TTL_SEC = 8 * 3600
QR_TTL_SEC = 300
_ADMIN_USER = "root"
_ADMIN_PASS = "root"
_sessions: dict[str, float] = {}
_qr_challenges: dict[str, dict[str, Any]] = {}
_webauthn_path = Path(__file__).resolve().parent.parent / "data" / "admin_webauthn.json"

def _admin_key_expected() -> str:
    key = (get_settings().admin_api_key or "").strip()
    if not key:
        raise HTTPException(status_code=503, detail="ADMIN_API_KEY не настроен на сервере")
    return key

def verify_admin_key_header(x_admin_key: str | None) -> None:
    expected = _admin_key_expected()
    got = (x_admin_key or "").strip()
    if not got or not hmac.compare_digest(got, expected):
        raise HTTPException(status_code=401, detail="Неверный или отсутствует X-Admin-Key")

def _session_sign(payload: str, secret: str) -> str:
    return hmac.new(secret.encode(), payload.encode(), hashlib.sha256).hexdigest()

def issue_session_token() -> str:
    secret = _admin_key_expected()
    exp = int(time.time()) + SESSION_TTL_SEC
    payload = f"{exp}|admin"
    sig = _session_sign(payload, secret)
    raw = f"{payload}|{sig}"
    token = base64.urlsafe_b64encode(raw.encode()).decode()
    _sessions[token] = float(exp)
    return token

def verify_session_token(x_admin_session: str | None) -> None:
    if not x_admin_session:
        raise HTTPException(status_code=401, detail="Требуется сессия админ-панели")
    secret = _admin_key_expected()
    try:
        raw = base64.urlsafe_b64decode(x_admin_session.encode()).decode()
        exp_s, role, sig = raw.split("|", 2)
        if role != "admin":
            raise ValueError("role")
        payload = f"{exp_s}|{role}"
        if not hmac.compare_digest(sig, _session_sign(payload, secret)):
            raise ValueError("sig")
        if int(exp_s) < time.time():
            raise ValueError("exp")
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Сессия недействительна или истекла") from exc

def require_admin_access(
    x_admin_key: str | None = Header(default=None, alias="X-Admin-Key"),
    x_admin_session: str | None = Header(default=None, alias="X-Admin-Session"),
) -> None:
    verify_admin_key_header(x_admin_key)
    verify_session_token(x_admin_session)

def login_password(username: str, password: str) -> dict:
    user = (username or "").strip()
    if user != _ADMIN_USER or password != _ADMIN_PASS:
        raise HTTPException(status_code=401, detail="Неверный логин или пароль")
    token = issue_session_token()
    return {"ok": True, "session": token, "method": "password", "user": user}

def _load_webauthn() -> dict:
    if not _webauthn_path.is_file():
        return {"credentials": []}
    try:
        return json.loads(_webauthn_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {"credentials": []}

def _save_webauthn(data: dict) -> None:
    _webauthn_path.parent.mkdir(parents=True, exist_ok=True)
    _webauthn_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

def webauthn_register(credential_id: str, public_key: str, label: str = "admin") -> dict:
    cid = (credential_id or "").strip()
    pk = (public_key or "").strip()
    if not cid or not pk:
        raise HTTPException(status_code=400, detail="credential_id и public_key обязательны")
    data = _load_webauthn()
    creds = data.setdefault("credentials", [])
    creds = [c for c in creds if c.get("credential_id") != cid]
    creds.append({"credential_id": cid, "public_key": pk, "label": label, "created_at": int(time.time())})
    data["credentials"] = creds
    _save_webauthn(data)
    token = issue_session_token()
    return {"ok": True, "session": token, "method": "webauthn", "registered": True}

def webauthn_login(credential_id: str) -> dict:
    cid = (credential_id or "").strip()
    data = _load_webauthn()
    creds = data.get("credentials") or []
    if not any(c.get("credential_id") == cid for c in creds):
        raise HTTPException(status_code=401, detail="Отпечаток не зарегистрирован")
    token = issue_session_token()
    return {"ok": True, "session": token, "method": "webauthn"}

def webauthn_status() -> dict:
    data = _load_webauthn()
    creds = data.get("credentials") or []
    return {"registered": len(creds) > 0, "count": len(creds)}

def qr_start(public_base: str | None = None) -> dict:
    challenge = secrets.token_urlsafe(16)
    exp = time.time() + QR_TTL_SEC
    settings = get_settings()
    base = (public_base or settings.public_host or "").rstrip("/") or "http://127.0.0.1:8000"
    confirm_url = f"{base}/api/admin/auth/qr/confirm-page?challenge={challenge}"
    _qr_challenges[challenge] = {"status": "pending", "exp": exp, "confirm_url": confirm_url}
    return {
        "challenge": challenge,
        "expires_in": QR_TTL_SEC,
        "confirm_url": confirm_url,
        "svg_url": f"{base}/api/admin/auth/qr/svg/{challenge}",
        "qr_payload": json.dumps({"type": "nt-admin", "challenge": challenge, "api": base}, ensure_ascii=False),
    }

def qr_poll(challenge: str) -> dict:
    entry = _qr_challenges.get(challenge)
    if not entry:
        return {"status": "missing"}
    if entry["exp"] < time.time():
        _qr_challenges.pop(challenge, None)
        return {"status": "expired"}
    if entry.get("status") == "ok" and entry.get("session"):
        return {"status": "ok", "session": entry["session"]}
    return {"status": entry.get("status", "pending")}

def qr_confirm(challenge: str) -> dict:
    entry = _qr_challenges.get(challenge)
    if not entry:
        raise HTTPException(status_code=404, detail="QR-сессия не найдена")
    if entry["exp"] < time.time():
        _qr_challenges.pop(challenge, None)
        raise HTTPException(status_code=410, detail="QR-код истёк")
    token = issue_session_token()
    entry["status"] = "ok"
    entry["session"] = token
    return {"ok": True, "session": token}
