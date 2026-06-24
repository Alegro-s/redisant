from __future__ import annotations

from sqlalchemy.orm import Session

from app.db.models import User, UserRole
from app.services.telegram_bot import bot_configured

def settings_dict(user: User) -> dict:
    linked = bool(user.telegram_chat_id)
    return {
        "telegram_linked": linked,
        "telegram_notify": bool(user.telegram_notify) if linked else False,
        "notify_security": bool(getattr(user, "notify_security", True)),
        "notify_messages": bool(getattr(user, "notify_messages", False)),
        "bot_configured": bot_configured(),
    }

def update_settings(
    db: Session,
    user: User,
    *,
    notify_security: bool | None,
    notify_messages: bool | None,
) -> dict:
    if notify_security is not None:
        user.notify_security = notify_security
    if notify_messages is not None:
        user.notify_messages = notify_messages
    db.add(user)
    db.commit()
    db.refresh(user)
    return settings_dict(user)

def list_subscribers(db: Session) -> list[dict]:
    rows = (
        db.query(User)
        .filter(
            User.telegram_chat_id.isnot(None),
            User.telegram_notify.is_(True),
            User.is_active.is_(True),
        )
        .order_by(User.username)
        .all()
    )
    return [
        {
            "username": u.username,
            "display_name": u.display_name,
            "role": u.role.value,
            "telegram_chat_id": u.telegram_chat_id,
            "notify_security": bool(getattr(u, "notify_security", True)),
            "notify_messages": bool(getattr(u, "notify_messages", False)),
        }
        for u in rows
        if u.role != UserRole.scammer
    ]
