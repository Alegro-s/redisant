from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.config import get_settings
from app.db.models import Alert, User, UserRole
from app.services.mattermost_client import (
    get_mattermost_headers,
    get_or_create_dm_channel,
    post_to_channel,
)

def _severity_color(severity: str) -> str:
    return {
        "critical": "#D0021B",
        "high": "#E67E22",
        "medium": "#F5A623",
        "low": "#7ED321",
    }.get(severity, "#439FE0")

def post_to_security_channel(message: str, attachment_color: str = "#439FE0", attachment_text: str | None = None) -> bool:
    """Пост в канал Security Alerts (видят только админы)."""
    settings = get_settings()
    if not settings.mattermost_bot_token or not settings.mattermost_alert_channel_id:
        return False

    props: dict = {}
    if attachment_text:
        props["attachments"] = [{"color": attachment_color, "text": attachment_text}]
    return post_to_channel(settings.mattermost_alert_channel_id, message, props=props or None)

def dm_user(mm_user_id: str, message: str, *, attachment_color: str = "#439FE0") -> bool:
    """Личное сообщение от бота админу."""
    channel_id = get_or_create_dm_channel(mm_user_id)
    if not channel_id:
        return False
    props = {"attachments": [{"color": attachment_color, "text": message[:500]}]}
    return post_to_channel(channel_id, message, props=props)

def dm_all_admins(db: Session, message: str, *, attachment_color: str = "#439FE0") -> int:
    """Отправить DM всем admin/super_admin с привязанным mattermost_user_id."""
    settings = get_settings()
    if not settings.mattermost_dm_alerts or not settings.mattermost_bot_token:
        return 0

    admins = (
        db.query(User)
        .filter(User.role.in_([UserRole.admin, UserRole.super_admin]), User.is_active.is_(True))
        .all()
    )
    sent = 0
    for admin in admins:
        if admin.mattermost_user_id and dm_user(admin.mattermost_user_id, message, attachment_color=attachment_color):
            sent += 1
    return sent

def notify_user_blocked(
    username: str,
    display_name: str,
    reason: str,
    *,
    actor: str = "admin_panel",
    mattermost_deactivated: bool = True,
) -> bool:
    when = datetime.now(UTC).strftime("%d.%m.%Y %H:%M UTC")
    mm_status = "аккаунт Mattermost отключён" if mattermost_deactivated else "Mattermost не синхронизирован"
    message = (
        f"### :no_entry: Пользователь заблокирован\n"
        f"**Кто:** `{username}` ({display_name})\n"
        f"**Причина:** {reason}\n"
        f"**Кем:** {actor}\n"
        f"**Время:** {when}\n"
        f"**Статус:** {mm_status}"
    )
    return post_to_security_channel(
        message,
        attachment_color="#D0021B",
        attachment_text=f"Блокировка: {username}. Причина: {reason}",
    )

def notify_user_unblocked(
    username: str,
    display_name: str,
    *,
    actor: str = "admin_panel",
    mattermost_reactivated: bool = True,
) -> bool:
    when = datetime.now(UTC).strftime("%d.%m.%Y %H:%M UTC")
    mm_status = "аккаунт Mattermost снова активен" if mattermost_reactivated else "Mattermost не синхронизирован"
    message = (
        f"### :white_check_mark: Пользователь разблокирован\n"
        f"**Кто:** `{username}` ({display_name})\n"
        f"**Кем:** {actor}\n"
        f"**Время:** {when}\n"
        f"**Статус:** {mm_status}"
    )
    return post_to_security_channel(
        message,
        attachment_color="#7ED321",
        attachment_text=f"Разблокировка: {username}",
    )

def _format_alert_message(alert: Alert, sender_name: str | None = None) -> str:
    sender_line = f"**Отправитель:** {sender_name}\n" if sender_name else ""
    return (
        f"### :warning: {alert.title_ru}\n"
        f"**Уровень:** {alert.severity.value}\n"
        f"{sender_line}"
        f"**Пояснение (XAI):** {alert.explanation_ru}\n"
        f"**Тип:** `{alert.alert_type}`"
    )

def post_alert_to_mattermost(db: Session, alert: Alert, sender_name: str | None = None) -> bool:
    settings = get_settings()
    if not settings.mattermost_bot_token or not settings.mattermost_alert_channel_id:
        return False

    text = _format_alert_message(alert, sender_name)
    color = _severity_color(alert.severity.value)
    channel_ok = post_to_security_channel(text, attachment_color=color, attachment_text=alert.explanation_ru)
    dm_all_admins(db, text, attachment_color=color)
    return channel_ok
