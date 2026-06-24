from __future__ import annotations

import secrets
from datetime import UTC, datetime, timedelta

import httpx
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db.models import User

_LINK_TTL = timedelta(minutes=20)

def get_bot_username() -> str | None:
    token = (get_settings().telegram_bot_token or "").strip()
    if not token:
        return None
    try:
        with httpx.Client(timeout=10) as client:
            res = client.get(f"https://api.telegram.org/bot{token}/getMe")
        if res.status_code != 200:
            return None
        data = res.json()
        if data.get("ok"):
            return data.get("result", {}).get("username")
    except httpx.HTTPError:
        return None
    return None

def create_link_code(db: Session, user: User) -> dict:
    code = secrets.token_hex(4).upper()
    user.telegram_link_code = code
    user.telegram_link_expires = datetime.now(UTC) + _LINK_TTL
    db.add(user)
    db.commit()
    bot = get_bot_username() or "NeuralTrustBot"
    deep_link = f"https://t.me/{bot}?start=link_{code}"
    return {
        "code": code,
        "bot_username": bot,
        "deep_link": deep_link,
        "expires_at": user.telegram_link_expires.isoformat(),
        "instruction": f"Откройте Telegram и нажмите «Подключить» или отправьте боту: /start link_{code}",
    }

def confirm_link_by_code(db: Session, code: str, chat_id: str, tg_user_id: str) -> tuple[bool, str, User | None]:
    normalized = code.strip().upper()
    if normalized.lower().startswith("link_"):
        normalized = normalized[5:].upper()
    user = db.query(User).filter(User.telegram_link_code == normalized).first()
    if not user:
        return False, "Код не найден или уже использован.", None
    expires = user.telegram_link_expires
    if expires and expires < datetime.now(UTC):
        user.telegram_link_code = None
        user.telegram_link_expires = None
        db.commit()
        return False, "Код истёк. Запросите новый в мессенджере.", None
    user.telegram_chat_id = str(chat_id)
    user.telegram_user_id = str(tg_user_id)
    user.telegram_notify = True
    user.notify_security = True
    user.telegram_link_code = None
    user.telegram_link_expires = None
    db.commit()
    return True, f"Привязано: {user.display_name} (@{user.username})", user

def unlink_telegram(db: Session, user: User) -> None:
    user.telegram_chat_id = None
    user.telegram_notify = False
    user.telegram_link_code = None
    user.telegram_link_expires = None
    db.add(user)
    db.commit()
