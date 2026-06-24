from __future__ import annotations

import httpx

from app.config import get_settings

def get_mattermost_headers() -> dict[str, str] | None:
    settings = get_settings()
    if not settings.mattermost_bot_token:
        return None
    return {"Authorization": f"Bearer {settings.mattermost_bot_token}"}

_bot_user_id: str | None = None

def get_bot_user_id() -> str | None:
    global _bot_user_id
    if _bot_user_id:
        return _bot_user_id
    headers = get_mattermost_headers()
    if not headers:
        return None
    settings = get_settings()
    try:
        with httpx.Client(timeout=10) as client:
            res = client.get(f"{settings.mattermost_url.rstrip('/')}/api/v4/users/me", headers=headers)
            if res.status_code == 200:
                _bot_user_id = res.json().get("id")
                return _bot_user_id
    except httpx.HTTPError:
        return None
    return None

def fetch_user_by_username(username: str) -> dict | None:
    headers = get_mattermost_headers()
    if not headers:
        return None
    settings = get_settings()
    try:
        with httpx.Client(timeout=10) as client:
            res = client.get(
                f"{settings.mattermost_url.rstrip('/')}/api/v4/users/username/{username}",
                headers=headers,
            )
            if res.status_code == 200:
                return res.json()
    except httpx.HTTPError:
        return None
    return None

def get_or_create_dm_channel(target_user_id: str) -> str | None:
    bot_id = get_bot_user_id()
    if not bot_id or not target_user_id:
        return None
    headers = get_mattermost_headers()
    if not headers:
        return None
    settings = get_settings()
    user_ids = sorted([bot_id, target_user_id])
    try:
        with httpx.Client(timeout=10) as client:
            res = client.post(
                f"{settings.mattermost_url.rstrip('/')}/api/v4/channels/direct",
                json=user_ids,
                headers=headers,
            )
            if res.status_code in (200, 201):
                return res.json().get("id")
    except httpx.HTTPError:
        return None
    return None

def post_to_channel(channel_id: str, message: str, *, props: dict | None = None) -> bool:
    headers = get_mattermost_headers()
    if not headers:
        return False
    settings = get_settings()
    payload: dict = {"channel_id": channel_id, "message": message}
    if props:
        payload["props"] = props
    try:
        with httpx.Client(timeout=10) as client:
            res = client.post(
                f"{settings.mattermost_url.rstrip('/')}/api/v4/posts",
                json=payload,
                headers=headers,
            )
            return res.status_code == 201
    except httpx.HTTPError:
        return False
