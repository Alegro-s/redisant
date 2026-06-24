from __future__ import annotations

import time

_unlock_until: dict[str, float] = {}
_TTL_SEC = 30 * 60


def try_unlock(admin_api_key: str, view_key: str, expected_view_key: str) -> bool:
    if not expected_view_key or view_key != expected_view_key:
        return False
    _unlock_until[admin_api_key] = time.time() + _TTL_SEC
    return True


def admin_can_view_messages(admin_api_key: str) -> bool:
    until = _unlock_until.get(admin_api_key, 0.0)
    return time.time() < until


def unlock_ttl_remaining(admin_api_key: str) -> int:
    until = _unlock_until.get(admin_api_key, 0.0)
    return max(0, int(until - time.time()))
