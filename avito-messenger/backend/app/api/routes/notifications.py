from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db.models import User
from app.db.session import get_db
from app.services.admin_auth import require_admin_key
from app.services.inference_health import inference_nodes_status
from app.services.notification_prefs import list_subscribers
from app.services.telegram_bot import bot_configured, send_telegram_to_chat, set_webhook
from app.services.telegram_link import get_bot_username
from app.services.telegram_notify import _telegram_configured, send_telegram_message

router = APIRouter(
    prefix="/api/notifications",
    tags=["notifications"],
    dependencies=[Depends(require_admin_key)],
)

class NotificationSettingsPatch(BaseModel):
    notify_security: bool | None = None
    notify_messages: bool | None = None

class TestUserIn(BaseModel):
    username: str = Field(..., min_length=1, max_length=64)
    title: str = "Тест Neural Trust"
    body: str = "Проверка личного уведомления из админ-панели."

class WebhookSetupIn(BaseModel):
    public_base_url: str = Field(..., min_length=8)

@router.get("/status")
def notifications_status(db: Session = Depends(get_db)) -> dict:
    settings = get_settings()
    subs = list_subscribers(db)
    return {
        "telegram": {
            "bot_configured": bot_configured(),
            "bot_username": get_bot_username(),
            "ops_chat_configured": _telegram_configured(),
            "alert_chat_id_set": bool(settings.telegram_alert_chat_id),
            "linked_users": len(subs),
        },
        "inference": inference_nodes_status(),
        "subscribers_preview": subs[:8],
    }

@router.get("/subscribers")
def notifications_subscribers(db: Session = Depends(get_db)) -> dict:
    return {"subscribers": list_subscribers(db)}

@router.post("/test/ops-chat")
def test_ops_chat() -> dict:
    if not _telegram_configured():
        raise HTTPException(status_code=503, detail="TELEGRAM_BOT_TOKEN и TELEGRAM_ALERT_CHAT_ID не заданы")
    ok = send_telegram_message("🧪 <b>Neural Trust</b>\nТест ops-канала из панели уведомлений.")
    return {"ok": ok}

@router.post("/test/user")
def test_user_notification(payload: TestUserIn, db: Session = Depends(get_db)) -> dict:
    user = db.query(User).filter(User.username == payload.username).first()
    if not user or not user.telegram_chat_id:
        raise HTTPException(status_code=404, detail="Пользователь не привязан к Telegram")
    ok = send_telegram_to_chat(user.telegram_chat_id, f"🧪 <b>{payload.title}</b>\n{payload.body}")
    return {"ok": ok, "username": user.username}

@router.post("/telegram/webhook")
def setup_telegram_webhook(payload: WebhookSetupIn) -> dict:
    if not bot_configured():
        raise HTTPException(status_code=503, detail="TELEGRAM_BOT_TOKEN не задан")
    secret = (get_settings().telegram_webhook_secret or "").strip()
    ok, detail = set_webhook(payload.public_base_url.strip(), secret)
    if not ok:
        raise HTTPException(status_code=502, detail=detail)
    return {"ok": True, "webhook_url": detail}
