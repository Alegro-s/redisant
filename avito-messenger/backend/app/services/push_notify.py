from __future__ import annotations

import json
from pathlib import Path

import httpx

from app.config import get_settings
from app.db.models import Alert

_DEVICE_TOKENS: dict[str, set[str]] = {}

def register_device_token(username: str, token: str) -> None:
    if not username or not token:
        return
    bucket = _DEVICE_TOKENS.setdefault(username, set())
    bucket.add(token.strip())

def unregister_device_token(username: str, token: str) -> None:
    bucket = _DEVICE_TOKENS.get(username)
    if not bucket:
        return
    bucket.discard(token.strip())
    if not bucket:
        _DEVICE_TOKENS.pop(username, None)

def debug_device_tokens() -> dict[str, int]:
    return {username: len(tokens) for username, tokens in _DEVICE_TOKENS.items() if tokens}

def _fcm_project_id() -> str:
    settings = get_settings()
    if settings.fcm_project_id:
        return settings.fcm_project_id.strip()
    path = settings.fcm_service_account_file.strip()
    if not path:
        return ""
    p = Path(path)
    if not p.is_file():
        return ""
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
        return str(data.get("project_id") or "").strip()
    except Exception:
        return ""

def _send_fcm_v1(token: str, title: str, body: str) -> bool:
    settings = get_settings()
    service_account_file = settings.fcm_service_account_file.strip()
    if not service_account_file:
        return False
    project_id = _fcm_project_id()
    if not project_id:
        return False
    try:
        from google.auth.transport.requests import Request
        from google.oauth2 import service_account

        creds = service_account.Credentials.from_service_account_file(
            service_account_file,
            scopes=["https://www.googleapis.com/auth/firebase.messaging"],
        )
        creds.refresh(Request())
        if not creds.token:
            return False
        payload = {
            "message": {
                "token": token,
                "notification": {"title": title[:120], "body": body[:350]},
                "data": {"kind": "security"},
                "android": {"priority": "high"},
            }
        }
        url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
        with httpx.Client(timeout=10) as client:
            res = client.post(
                url,
                headers={
                    "Authorization": f"Bearer {creds.token}",
                    "Content-Type": "application/json; charset=UTF-8",
                },
                json=payload,
            )
            return res.status_code == 200
    except Exception:
        return False

def _send_fcm_legacy(token: str, title: str, body: str) -> bool:
    settings = get_settings()
    if not settings.fcm_server_key:
        return False
    try:
        with httpx.Client(timeout=10) as client:
            res = client.post(
                "https://fcm.googleapis.com/fcm/send",
                headers={
                    "Authorization": f"key={settings.fcm_server_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "to": token,
                    "priority": "high",
                    "notification": {"title": title[:120], "body": body[:350]},
                    "data": {"kind": "security"},
                },
            )
            return res.status_code == 200
    except httpx.HTTPError:
        return False

def _send_fcm(token: str, title: str, body: str) -> bool:
    if _send_fcm_v1(token, title, body):
        return True
    return _send_fcm_legacy(token, title, body)

def push_message_to_user(username: str, title: str, body: str, *, kind: str = "message") -> int:
    tokens = list(_DEVICE_TOKENS.get(username, set()))
    if not tokens:
        return 0
    ok = 0
    for token in tokens:
        if _send_fcm(token, title, body):
            ok += 1
    return ok

def notify_admins_new_user(username: str, display_name: str, email: str | None) -> int:
    title = "YALGSI: новый пользователь"
    body = f"{display_name or username} (@{username})"
    if email:
        body += f" — {email}"
    sent = 0
    for admin in ("superadmin",):
        sent += push_message_to_user(admin, title, body)
    return sent

def push_alert_to_user(username: str, alert: Alert) -> int:
    tokens = list(_DEVICE_TOKENS.get(username, set()))
    if not tokens:
        return 0
    ok = 0
    for token in tokens:
        if _send_fcm(token, alert.title_ru, alert.explanation_ru):
            ok += 1
    return ok
