"""Проверка JWT платформы и квота Roza AI на auth-api."""

from __future__ import annotations

import os
from typing import Any

import httpx

_AUTH_BASE = (
    os.environ.get("ROZA_AUTH_API_URL")
    or os.environ.get("ROZA_AUTH_URL")
    or "http://127.0.0.1:8090"
).rstrip("/")
_INTROSPECT = f"{_AUTH_BASE}/auth/introspect"
_CONSUME = f"{_AUTH_BASE}/me/roza/consume"


def _estimate_tokens(text: str, reply: str = "") -> int:
    return max(80, (len(text) + len(reply)) // 4)


async def require_roza_user(authorization: str | None) -> dict[str, Any]:
    """Активная сессия + план/квота. Без токена — гостевой режим (если ROZA_ALLOW_GUEST=1)."""
    allow_guest = (os.environ.get("ROZA_ALLOW_GUEST") or "1").strip() in ("1", "true", "yes")
    if not authorization or not authorization.startswith("Bearer "):
        if allow_guest:
            return {"guest": True, "plan": "free", "tokens_limit": 0}
        raise PermissionError("Требуется вход: откройте личный кабинет Roza AI или приложение.")

    token = authorization[7:].strip()
    async with httpx.AsyncClient(timeout=12.0) as client:
        r = await client.get(_INTROSPECT, headers={"Authorization": f"Bearer {token}"})
        if r.status_code == 401:
            raise PermissionError("Сессия истекла. Войдите снова.")
        r.raise_for_status()
        data = r.json()
    if not data.get("active"):
        raise PermissionError("Сессия недействительна.")
    return data


async def consume_roza_tokens(authorization: str | None, user_text: str, reply: str = "") -> None:
    if not authorization or not authorization.startswith("Bearer "):
        return
    est = _estimate_tokens(user_text, reply)
    token = authorization[7:].strip()
    async with httpx.AsyncClient(timeout=12.0) as client:
        r = await client.post(
            _CONSUME,
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            json={"tokens": est},
        )
        if r.status_code == 429:
            body = r.json() if r.headers.get("content-type", "").startswith("application/json") else {}
            raise PermissionError(body.get("error") or "Дневной лимит токенов исчерпан.")
        if r.status_code >= 400:
            return
