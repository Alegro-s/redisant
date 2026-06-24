from __future__ import annotations

from copy import deepcopy
from datetime import UTC, datetime

from app.db.models import User

_INTERNAL_KEYS = frozenset(
    {
        "totp_secret",
        "totp_pending_secret",
        "email_verify_code",
        "email_verify_expires",
        "pending_email",
    }
)

DEFAULT_SETTINGS: dict = {
    "theme": "system",
    "font_scale": 1.0,
    "privacy": {
        "show_email": False,
        "show_username": True,
        "show_display_name": True,
        "show_last_seen": True,
    },
    "ai_shield_linked": True,
    "totp_enabled": False,
}

def get_settings(user: User) -> dict:
    base = deepcopy(DEFAULT_SETTINGS)
    raw = user.user_settings if isinstance(user.user_settings, dict) else {}
    base.update({k: v for k, v in raw.items() if k != "privacy"})
    if isinstance(raw.get("privacy"), dict):
        base["privacy"] = {**base["privacy"], **raw["privacy"]}
    return base

def save_settings(user: User, patch: dict) -> dict:
    raw = dict(user.user_settings or {})
    current = get_settings(user)
    for key, val in patch.items():
        if key == "privacy" and isinstance(val, dict):
            current["privacy"] = {**current.get("privacy", {}), **val}
        elif key not in _INTERNAL_KEYS:
            current[key] = val
    for key, val in current.items():
        if key not in _INTERNAL_KEYS:
            raw[key] = val
    if isinstance(current.get("privacy"), dict):
        raw["privacy"] = current["privacy"]
    user.user_settings = raw
    return current

def set_internal(user: User, **kwargs) -> None:
    raw = dict(user.user_settings or {})
    raw.update(kwargs)
    user.user_settings = raw

def totp_enabled(user: User) -> bool:
    return bool(get_settings(user).get("totp_enabled"))

def now_iso() -> str:
    return datetime.now(UTC).isoformat()
