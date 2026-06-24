from __future__ import annotations

import time
from uuid import UUID

from app.config import get_settings

_last_alert: dict[tuple[str, str], float] = {}

def should_emit_alert(sender_id: UUID | None, channel_key: str) -> bool:
    if sender_id is None:
        return True
    key = (str(sender_id), channel_key)
    now = time.time()
    cooldown = get_settings().alert_cooldown_sec
    prev = _last_alert.get(key)
    if prev and now - prev < cooldown:
        return False
    _last_alert[key] = now
    return True
