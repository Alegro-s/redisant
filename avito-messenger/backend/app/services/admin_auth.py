from __future__ import annotations

from fastapi import Header, HTTPException

from app.config import get_settings

def require_admin_key(x_admin_key: str | None = Header(default=None, alias="X-Admin-Key")) -> None:
    expected = (get_settings().admin_api_key or "").strip()
    if not expected:
        return
    if not x_admin_key or not x_admin_key.strip() or x_admin_key.strip() != expected:
        raise HTTPException(status_code=401, detail="Требуется X-Admin-Key")


def admin_key_from_header(x_admin_key: str | None = Header(default=None, alias="X-Admin-Key")) -> str | None:
    require_admin_key(x_admin_key)
    return x_admin_key.strip() if x_admin_key else None
