from __future__ import annotations

import html
import re

import httpx
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db.models import Alert, User, UserRole
from app.services.telegram_link import confirm_link_by_code

from app.services.password_auth import verify_password

_LINK_RE = re.compile(r"^/link(?:@\w+)?\s+(\S+)\s+(\S+)\s*$", re.I)

def _escape(text: str) -> str:
    return html.escape(text, quote=False)

def bot_configured() -> bool:
    return bool((get_settings().telegram_bot_token or "").strip())

def _relay_headers() -> dict[str, str]:
    secret = (get_settings().telegram_relay_secret or get_settings().telegram_webhook_secret or "").strip()
    return {"X-Relay-Secret": secret} if secret else {}

def _send_via_api(chat_id: str, text: str, *, parse_mode: str = "HTML") -> bool:
    token = (get_settings().telegram_bot_token or "").strip()
    if not token or not chat_id:
        return False
    payload = {
        "chat_id": chat_id,
        "text": text[:4096],
        "parse_mode": parse_mode,
        "disable_web_page_preview": True,
    }
    relay = (get_settings().telegram_relay_url or "").strip().rstrip("/")
    if relay:
        try:
            with httpx.Client(timeout=20) as client:
                res = client.post(f"{relay}/relay/send", json=payload, headers=_relay_headers())
                if res.status_code == 200:
                    data = res.json()
                    return bool(data.get("ok"))
        except httpx.HTTPError:
            pass
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    try:
        with httpx.Client(timeout=15) as client:
            res = client.post(url, json=payload)
            return res.status_code == 200 and res.json().get("ok") is True
    except httpx.HTTPError:
        return False

def send_telegram_to_chat(chat_id: str, text: str, *, parse_mode: str = "HTML") -> bool:
    return _send_via_api(chat_id, text, parse_mode=parse_mode)

def set_webhook(public_base_url: str, secret: str) -> tuple[bool, str]:
    settings = get_settings()
    token = (settings.telegram_bot_token or "").strip()
    if not token:
        return False, "TELEGRAM_BOT_TOKEN не задан"
    base = (settings.telegram_webhook_public_url or public_base_url).strip().rstrip("/")
    hook_url = f"{base}/webhooks/telegram/bot"
    try:
        with httpx.Client(timeout=20) as client:
            res = client.post(
                f"https://api.telegram.org/bot{token}/setWebhook",
                json={
                    "url": hook_url,
                    "secret_token": secret or None,
                    "allowed_updates": ["message"],
                    "drop_pending_updates": False,
                },
            )
            data = res.json()
            if data.get("ok"):
                return True, hook_url
            return False, data.get("description") or "setWebhook failed"
    except httpx.HTTPError as exc:
        return False, str(exc)

def link_user(db: Session, username: str, password: str, chat_id: str, tg_user_id: str) -> tuple[bool, str]:
    user = db.query(User).filter(User.username == username).first()
    if not user:
        return False, "Пользователь не найден."
    if not user.password_hash or not verify_password(password, user.password_hash):
        return False, "Неверный пароль."
    if not user.is_active:
        return False, "Аккаунт деактивирован."
    user.telegram_chat_id = str(chat_id)
    user.telegram_user_id = str(tg_user_id)
    user.telegram_notify = True
    db.commit()
    return True, f"Привязано: {_escape(user.display_name)} (@{username}). Уведомления включены."

def unlink_user(db: Session, chat_id: str) -> None:
    user = db.query(User).filter(User.telegram_chat_id == str(chat_id)).first()
    if user:
        user.telegram_chat_id = None
        user.telegram_notify = False
        db.commit()

def subscribers_for_alerts(db: Session) -> list[User]:
    q = db.query(User).filter(
        User.telegram_chat_id.isnot(None),
        User.telegram_notify.is_(True),
        User.is_active.is_(True),
    )
    return q.all()

def notify_superadmin_analyst_alert(db: Session, alert: Alert, sender_name: str | None = None) -> int:
    """Дублирует алерт в стиле «Информационный аналитик» для super_admin."""
    sent = 0
    sender_line = f"\n<b>Отправитель:</b> {_escape(sender_name)}" if sender_name else ""
    text = (
        f"📊 <b>Контроль безопасности</b>\n"
        f"<i>Информационный аналитик</i>\n\n"
        f"<b>{_escape(alert.title_ru)}</b>\n"
        f"Уровень: {_escape(alert.severity.value)}{sender_line}\n\n"
        f"{_escape(alert.explanation_ru[:1800])}\n\n"
        f"<i>Тот же сигнал доступен в мессенджере → «Контроль безопасности».</i>"
    )
    admins = (
        db.query(User)
        .filter(
            User.role == UserRole.super_admin,
            User.telegram_chat_id.isnot(None),
            User.telegram_notify.is_(True),
            User.is_active.is_(True),
        )
        .all()
    )
    for user in admins:
        if send_telegram_to_chat(user.telegram_chat_id, text):
            sent += 1
    return sent

def notify_subscribers_alert(db: Session, alert: Alert, sender_name: str | None = None) -> int:
    """Личные уведомления подписчикам (админы + все привязавшие /link)."""
    sent = 0
    sender_line = f"\n<b>От:</b> {_escape(sender_name)}" if sender_name else ""
    text = (
        f"🛡 <b>Neural Trust</b>\n"
        f"<b>{_escape(alert.title_ru)}</b>\n"
        f"Уровень: {_escape(alert.severity.value)}{sender_line}\n\n"
        f"{_escape(alert.explanation_ru[:1500])}"
    )
    for user in subscribers_for_alerts(db):
        if user.role == UserRole.scammer:
            continue
        if send_telegram_to_chat(user.telegram_chat_id, text):
            sent += 1
    return sent

def notify_user_direct(db: Session, username: str, title: str, body: str) -> bool:
    user = db.query(User).filter(User.username == username).first()
    if not user or not user.telegram_chat_id or not user.telegram_notify:
        return False
    text = f"📩 <b>{_escape(title)}</b>\n{_escape(body)}"
    return send_telegram_to_chat(user.telegram_chat_id, text)

def handle_bot_update(db: Session, update: dict) -> None:
    msg = update.get("message") or update.get("edited_message")
    if not msg or not msg.get("text"):
        return
    text = msg["text"].strip()
    chat = msg.get("chat") or {}
    chat_id = str(chat.get("id", ""))
    frm = msg.get("from") or {}
    tg_user_id = str(frm.get("id", ""))

    if text.startswith("/start"):
        parts = text.split(maxsplit=1)
        if len(parts) > 1 and parts[1].lower().startswith("link_"):
            ok, reply, _user = confirm_link_by_code(db, parts[1], chat_id, tg_user_id)
            send_telegram_to_chat(chat_id, f"✅ {_escape(reply)}" if ok else f"❌ {_escape(reply)}")
            return
        send_telegram_to_chat(
            chat_id,
            "🛡 <b>Neural Trust Bot</b>\n\n"
            "Привязка аккаунта мессенджера:\n"
            "1. В caht: Настройки → Уведомления → «Подключить Telegram»\n"
            "2. Или команда: <code>/link логин пароль</code>\n"
            "   (тот же пароль, что при входе в приложение)\n\n"
            "Команды:\n"
            "/status — статус подписки\n"
            "/unlink — отключить уведомления\n"
            "/help — справка",
        )
        return

    if text.startswith("/help"):
        send_telegram_to_chat(
            chat_id,
            "Привязка: <code>/link superadmin Admin123!</code>\n"
            "Пароль — тот же, что при входе в caht.\n"
            "Либо откройте deep-link из настроек уведомлений в приложении.\n\n"
            "После привязки алерты безопасности приходят сюда.",
        )
        return

    if text.startswith("/status"):
        user = db.query(User).filter(User.telegram_chat_id == chat_id).first()
        if user:
            send_telegram_to_chat(
                chat_id,
                f"✅ Привязан: <b>{_escape(user.display_name)}</b> (@{user.username})\n"
                f"Уведомления: {'вкл' if user.telegram_notify else 'выкл'}",
            )
        else:
            send_telegram_to_chat(chat_id, "❌ Аккаунт не привязан. Используйте /link")
        return

    if text.startswith("/unlink"):
        unlink_user(db, chat_id)
        send_telegram_to_chat(chat_id, "Подписка отключена.")
        return

    m = _LINK_RE.match(text.replace("\n", " "))
    if m:
        ok, reply = link_user(db, m.group(1), m.group(2), chat_id, tg_user_id)
        send_telegram_to_chat(chat_id, reply if ok else f"❌ {reply}")
        return

    send_telegram_to_chat(chat_id, "Неизвестная команда. /help")
