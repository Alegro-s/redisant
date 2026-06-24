from __future__ import annotations

import base64
import os

from sqlalchemy.orm import Session

from app.db.models import ChannelKey


def logical_channel_id(*, channel_name: str, dialog_with: str | None, username: str) -> str:
    if dialog_with:
        a, b = sorted([username.strip(), dialog_with.strip()])
        return f"dm:{a}:{b}"
    return f"ch:{channel_name.strip()}"


def get_or_create_channel_key(db: Session, channel_id: str) -> bytes:
    row = db.get(ChannelKey, channel_id)
    if row:
        return base64.urlsafe_b64decode(row.key_b64.encode("ascii"))
    key = os.urandom(32)
    db.add(ChannelKey(channel_id=channel_id, key_b64=base64.urlsafe_b64encode(key).decode("ascii")))
    db.commit()
    return key


def channel_key_b64(db: Session, channel_id: str) -> str:
    key = get_or_create_channel_key(db, channel_id)
    return base64.urlsafe_b64encode(key).decode("ascii")
