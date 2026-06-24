from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy.orm import Session

from app.db.models import ChatPresence, ChatReadState

_PRESENCE_TTL_SEC = 35

def touch_presence(db: Session, username: str, *, online: bool = True) -> None:
    row = db.get(ChatPresence, username)
    now = datetime.now(UTC)
    if row is None:
        db.add(ChatPresence(username=username, last_seen=now, is_online=online))
    else:
        row.last_seen = now
        row.is_online = online
    db.commit()

def presence_online(db: Session, username: str) -> bool:
    row = db.get(ChatPresence, username)
    if not row or not row.is_online:
        return False
    age = (datetime.now(UTC) - row.last_seen).total_seconds()
    return age <= _PRESENCE_TTL_SEC

def set_read(db: Session, username: str, channel_key: str, last_message_id: str | UUID | None) -> None:
    msg_id = None
    if last_message_id:
        try:
            msg_id = UUID(str(last_message_id))
        except ValueError:
            msg_id = None
    row = (
        db.query(ChatReadState)
        .filter(ChatReadState.username == username, ChatReadState.channel_key == channel_key)
        .first()
    )
    now = datetime.now(UTC)
    if row is None:
        db.add(
            ChatReadState(
                username=username,
                channel_key=channel_key,
                last_message_id=msg_id,
                read_at=now,
            )
        )
    else:
        row.last_message_id = msg_id
        row.read_at = now
    db.commit()

def read_at_for(db: Session, username: str, channel_key: str) -> datetime | None:
    row = (
        db.query(ChatReadState)
        .filter(ChatReadState.username == username, ChatReadState.channel_key == channel_key)
        .first()
    )
    return row.read_at if row else None

def read_states_for_channel(db: Session, channel_key: str, exclude_username: str) -> list[ChatReadState]:
    return (
        db.query(ChatReadState)
        .filter(ChatReadState.channel_key == channel_key, ChatReadState.username != exclude_username)
        .order_by(ChatReadState.read_at.desc())
        .all()
    )
