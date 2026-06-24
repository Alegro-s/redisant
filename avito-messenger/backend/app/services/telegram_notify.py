from __future__ import annotations

import html

from app.config import get_settings
from app.db.models import Alert
from app.services.telegram_bot import _send_via_api

def _escape(text: str) -> str:
    return html.escape(text, quote=False)

def _telegram_configured() -> bool:
    s = get_settings()
    return bool(s.telegram_bot_token and s.telegram_alert_chat_id and s.telegram_alerts_enabled)

def send_telegram_message(text: str, *, parse_mode: str = "HTML") -> bool:
    settings = get_settings()
    if not _telegram_configured():
        return False
    return _send_via_api(settings.telegram_alert_chat_id, text, parse_mode=parse_mode)

def _is_compromise_alert(alert: Alert) -> bool:
    if alert.alert_type in ("bec_intent", "metadata_anomaly", "style_anomaly", "synthetic_text"):
        if alert.severity.value in ("critical", "high"):
            return True
    return alert.alert_type == "bec_intent"

def format_alert_message(alert: Alert, sender_name: str | None = None) -> str:
    sender_line = f"\n<b>Отправитель:</b> {_escape(sender_name)}" if sender_name else ""
    headline = "🚨 <b>Возможная компрометация аккаунта</b>" if _is_compromise_alert(alert) else f"⚠️ <b>{_escape(alert.title_ru)}</b>"
    return (
        f"{headline}\n"
        f"<b>Сигнал:</b> {_escape(alert.title_ru)}\n"
        f"<b>Уровень:</b> {_escape(alert.severity.value)}\n"
        f"<b>Тип:</b> <code>{_escape(alert.alert_type)}</code>"
        f"{sender_line}\n\n"
        f"<b>Пояснение:</b>\n{_escape(alert.explanation_ru)}\n\n"
        f"<i>Рекомендуется проверить учётную запись и при необходимости заблокировать в админ-панели.</i>"
    )

def send_alert_to_telegram(alert: Alert, sender_name: str | None = None) -> bool:
    return send_telegram_message(format_alert_message(alert, sender_name))

def notify_blocked_telegram(
    username: str,
    display_name: str,
    reason: str,
    *,
    actor: str = "admin_panel",
) -> bool:
    text = (
        f"🚫 <b>Пользователь заблокирован</b>\n"
        f"<b>Кто:</b> <code>{_escape(username)}</code> ({_escape(display_name)})\n"
        f"<b>Причина:</b> {_escape(reason)}\n"
        f"<b>Кем:</b> {_escape(actor)}"
    )
    return send_telegram_message(text)

def notify_compromise_hint(username: str, display_name: str, risk_pct: int) -> bool:
    text = (
        f"🚨 <b>Подозрение на взлом / BEC</b>\n"
        f"<b>Аккаунт:</b> <code>{_escape(username)}</code> ({_escape(display_name)})\n"
        f"<b>Риск:</b> {risk_pct}%\n"
        f"<i>Проверьте активность в Mattermost и при необходимости заблокируйте пользователя.</i>"
    )
    return send_telegram_message(text)

def notify_unblocked_telegram(
    username: str,
    display_name: str,
    *,
    actor: str = "admin_panel",
) -> bool:
    text = (
        f"✅ <b>Пользователь разблокирован</b>\n"
        f"<b>Кто:</b> <code>{_escape(username)}</code> ({_escape(display_name)})\n"
        f"<b>Кем:</b> {_escape(actor)}"
    )
    return send_telegram_message(text)
