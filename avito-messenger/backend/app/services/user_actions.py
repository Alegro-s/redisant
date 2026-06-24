import uuid
from datetime import UTC, datetime

import httpx
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db.models import AuditLog, User, UserRole
from app.services.mattermost_notify import (
    get_mattermost_headers,
    notify_user_blocked,
    notify_user_unblocked,
)
from app.services.telegram_notify import notify_blocked_telegram, notify_unblocked_telegram

def _cannot_block(user: User) -> None:
    if user.role in (UserRole.admin, UserRole.super_admin):
        raise HTTPException(status_code=400, detail="Нельзя заблокировать администратора")

def _log_action(db: Session, action: str, username: str, details: str) -> None:
    db.add(
        AuditLog(
            id=uuid.uuid4(),
            action=action,
            target_username=username,
            actor_username="admin_panel",
            details=details,
        )
    )

def _resolve_mattermost_user_id(db: Session, user: User) -> str | None:
    if user.mattermost_user_id:
        return user.mattermost_user_id

    settings = get_settings()
    headers = get_mattermost_headers()
    if not headers:
        return None

    try:
        with httpx.Client(timeout=10) as client:
            res = client.get(
                f"{settings.mattermost_url.rstrip('/')}/api/v4/users/username/{user.username}",
                headers=headers,
            )
            if res.status_code == 200:
                mm_id = res.json().get("id")
                if mm_id:
                    user.mattermost_user_id = mm_id
                    db.commit()
                return mm_id
    except httpx.HTTPError:
        return None
    return None

def _set_mattermost_active(mm_user_id: str, active: bool) -> bool:
    settings = get_settings()
    headers = get_mattermost_headers()
    if not headers or not mm_user_id:
        return False

    try:
        with httpx.Client(timeout=10) as client:
            res = client.put(
                f"{settings.mattermost_url.rstrip('/')}/api/v4/users/{mm_user_id}/active",
                json={"active": active},
                headers=headers,
            )
            return res.status_code == 200
    except httpx.HTTPError:
        return False

def block_user(db: Session, username: str, reason: str, actor: str = "admin_panel") -> User:
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    _cannot_block(user)

    user.is_blocked = True
    user.block_reason = reason
    user.blocked_at = datetime.now(UTC)
    user.is_active = False

    mm_id = _resolve_mattermost_user_id(db, user)
    mm_ok = _set_mattermost_active(mm_id, False) if mm_id else False

    details = f"Причина: {reason}. Mattermost: {'отключён' if mm_ok else 'не синхронизирован'}"
    _log_action(db, "user_blocked", username, details)
    db.commit()
    db.refresh(user)

    notify_user_blocked(
        user.username,
        user.display_name,
        reason,
        actor=actor,
        mattermost_deactivated=mm_ok,
    )
    notify_blocked_telegram(user.username, user.display_name, reason, actor=actor)
    return user

def unblock_user(db: Session, username: str, actor: str = "admin_panel") -> User:
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    user.is_blocked = False
    user.block_reason = None
    user.blocked_at = None
    user.is_active = True

    mm_id = _resolve_mattermost_user_id(db, user)
    mm_ok = _set_mattermost_active(mm_id, True) if mm_id else False

    details = f"Mattermost: {'включён' if mm_ok else 'не синхронизирован'}"
    _log_action(db, "user_unblocked", username, details)
    db.commit()
    db.refresh(user)

    notify_user_unblocked(
        user.username,
        user.display_name,
        actor=actor,
        mattermost_reactivated=mm_ok,
    )
    notify_unblocked_telegram(user.username, user.display_name, actor=actor)
    return user
