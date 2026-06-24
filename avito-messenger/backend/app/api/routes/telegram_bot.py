from __future__ import annotations

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db.session import get_db
from app.services.admin_auth import require_admin_key
from app.services.telegram_bot import bot_configured, handle_bot_update, set_webhook

router = APIRouter(prefix="/webhooks/telegram", tags=["telegram-bot"])

@router.post("/bot")
async def telegram_bot_webhook(
    request: Request,
    db: Session = Depends(get_db),
    x_telegram_bot_api_secret_token: str | None = Header(default=None),
) -> dict:
    secret = (get_settings().telegram_webhook_secret or "").strip()
    if secret and x_telegram_bot_api_secret_token != secret:
        raise HTTPException(status_code=401, detail="Invalid Telegram secret")
    try:
        update = await request.json()
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid JSON") from exc
    if isinstance(update, dict):
        handle_bot_update(db, update)
    return {"ok": True}

class WebhookSetupIn(BaseModel):
    public_base_url: str

@router.post("/bot/setup-webhook", dependencies=[Depends(require_admin_key)])
def setup_bot_webhook(body: WebhookSetupIn) -> dict:
    if not bot_configured():
        raise HTTPException(status_code=503, detail="TELEGRAM_BOT_TOKEN не задан")
    ok, detail = set_webhook(body.public_base_url.strip(), get_settings().telegram_webhook_secret or "")
    return {"ok": ok, "detail": detail}
