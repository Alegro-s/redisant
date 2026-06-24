from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db.models import Alert, AlertSeverity, User, UserRole
from app.db.session import get_db
from app.services.admin_auth import require_admin_key
from app.services.mattermost_client import get_bot_user_id, get_mattermost_headers
from app.services.mattermost_notify import post_to_security_channel
from app.services.telegram_bot import subscribers_for_alerts
from app.services.telegram_notify import _telegram_configured, send_telegram_message

router = APIRouter(prefix="/api/integrations", tags=["integrations"], dependencies=[Depends(require_admin_key)])

@router.get("/status")
def integrations_status(db: Session = Depends(get_db)) -> dict:
    settings = get_settings()
    admins = (
        db.query(User)
        .filter(User.role.in_([UserRole.admin, UserRole.super_admin]))
        .all()
    )
    admins_with_mm = sum(1 for a in admins if a.mattermost_user_id)
    scammers = db.query(User).filter(User.role == UserRole.scammer).count()

    return {
        "mattermost": {
            "url": settings.mattermost_url,
            "bot_token_set": bool(settings.mattermost_bot_token),
            "bot_connected": get_bot_user_id() is not None if settings.mattermost_bot_token else False,
            "alert_channel_id_set": bool(settings.mattermost_alert_channel_id),
            "dm_alerts_enabled": settings.mattermost_dm_alerts,
            "webhook_secret_set": bool(settings.mattermost_webhook_secret),
            "admins_total": len(admins),
            "admins_with_mattermost_id": admins_with_mm,
        },
        "telegram": {
            "alerts_enabled": settings.telegram_alerts_enabled,
            "bot_token_set": bool(settings.telegram_bot_token),
            "alert_chat_id_set": bool(settings.telegram_alert_chat_id),
            "ready": _telegram_configured(),
            "bot_webhook": "/webhooks/telegram/bot",
            "linked_users": len(subscribers_for_alerts(db)),
        },
        "email": {
            "mode": "demo_webhook_only",
            "webhook_secret_set": bool(settings.email_webhook_secret),
            "scammer_only": True,
            "gmail_imap": "deferred",
        },
        "users": {"scammers": scammers},
    }

@router.post("/test/mattermost")
def test_mattermost_post(db: Session = Depends(get_db)) -> dict:
    if not get_mattermost_headers():
        raise HTTPException(status_code=503, detail="MATTERMOST_BOT_TOKEN не задан")
    ok = post_to_security_channel(
        "### 🧪 Тест AI Shield\nПроверка канала **Security Alerts**.",
        attachment_color="#439FE0",
    )
    return {"ok": ok, "channel": "security_alerts"}

@router.post("/test/telegram")
def test_telegram() -> dict:
    if not _telegram_configured():
        raise HTTPException(
            status_code=503,
            detail="Задайте TELEGRAM_BOT_TOKEN и TELEGRAM_ALERT_CHAT_ID в .env",
        )
    ok = send_telegram_message(
        "🧪 <b>AI Shield</b>\nТест уведомлений о мошенниках в Telegram."
    )
    return {"ok": ok}

@router.post("/test/alert-pipeline")
def test_full_alert_pipeline(db: Session = Depends(get_db)) -> dict:
    """Пробный алерт через весь пайплайн (MM + Telegram + DM)."""
    from app.services.alert_delivery import deliver_alert

    alert = Alert(
        severity=AlertSeverity.medium,
        alert_type="test",
        title_ru="Тестовый алерт",
        explanation_ru="Проверка доставки в Mattermost и Telegram.",
        related_message_ids=[],
        target_user_ids=[],
        delivered=False,
    )
    db.add(alert)
    db.flush()
    deliver_alert(db, alert, sender=None)
    db.refresh(alert)
    return {"ok": alert.delivered, "alert_id": str(alert.id)}
