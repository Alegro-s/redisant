from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Request

from fastapi.responses import JSONResponse

from sqlalchemy.orm import Session

from app.config import get_settings

from app.db.models import MessageChannel, User

from app.db.session import get_db

from app.schemas.integrations import EmailWebhookIn, TelegramWebhookIn

from app.schemas.message import MessageIngest, MessageResponse

from app.services.ingest_pipeline import process_incoming_message
from app.services.messages import ingest_message, resolve_sender
from app.services.scammer_guard import require_scammer_sender

router = APIRouter(prefix="/webhooks", tags=["webhooks"])

settings = get_settings()

def _check_secret(provided: str | None, expected: str) -> None:

    if expected and provided != expected:

        raise HTTPException(status_code=401, detail="Неверный секрет webhook")

@router.post("/mattermost")

async def mattermost_outgoing(request: Request, db: Session = Depends(get_db)):

    """

    Mattermost Outgoing Webhook.

    Возвращает JSON с полем text — Mattermost покажет его в канале.

    """

    form = await request.form()

    data: dict[str, Any] = dict(form) if form else {}

    if not data:

        data = await request.json()

    token = data.get("token", "")

    if settings.mattermost_webhook_secret and token != settings.mattermost_webhook_secret:

        raise HTTPException(status_code=401, detail="Неверный токен webhook")

    text = (data.get("text") or "").strip()

    if not text:

        text = "(пустое сообщение)"

    username = data.get("user_name")

    sender = resolve_sender(

        db,

        MessageIngest(

            username=username,

            body=text,

            metadata={"user_id": data.get("user_id"), "channel_id": data.get("channel_id")},

        ),

    )

    if sender and sender.is_blocked:

        return JSONResponse(

            {

                "text": (

                    f"⛔ **{sender.username}** заблокирован в AI Shield.\n"

                    f"Причина: {sender.block_reason or 'не указана'}\n"

                    f"Сообщение не обработано."

                ),

                "username": "AI Shield",

            }

        )

    payload = MessageIngest(

        username=username,

        channel=MessageChannel.mattermost,

        external_id=data.get("post_id"),

        body=text,

        metadata={

            "channel_id": data.get("channel_id"),

            "channel_name": data.get("channel_name"),

            "user_id": data.get("user_id"),

            "team_id": data.get("team_id"),

            "trigger_word": data.get("trigger_word"),

        },

        raw_payload=dict(data),

    )

    message = ingest_message(db, payload)

    process_incoming_message(db, message)

    return MessageResponse(

        id=message.id,

        channel=message.channel,

        body=message.body,

        created_at=message.created_at,

        analyzed=True,

    )

@router.post("/email", response_model=MessageResponse)

def email_incoming(body: EmailWebhookIn, db: Session = Depends(get_db)) -> MessageResponse:

    """

    Приём email для демо (без IMAP). Вызывайте из скрипта или Postman.

    Типичный сценарий: scammer1 шлёт письмо «от CEO».

    """

    _check_secret(body.secret, settings.email_webhook_secret)
    require_scammer_sender(db, body.username, channel_label="email")

    full_body = body.body

    if body.subject:

        full_body = f"Тема: {body.subject}\n\n{body.body}"

    meta = {

        "from_email": body.from_email,

        "from_name": body.from_name,

        "to_email": body.to_email,

        "subject": body.subject,

    }

    payload = MessageIngest(

        username=body.username,

        channel=MessageChannel.email,

        external_id=f"email-{body.from_email}-{body.subject or 'no-subject'}",

        body=full_body,

        metadata=meta,

        raw_payload=body.model_dump(),

        impersonates_username=body.impersonates_username,

    )

    message = ingest_message(db, payload)

    process_incoming_message(db, message)

    return MessageResponse(

        id=message.id,

        channel=message.channel,

        body=message.body,

        created_at=message.created_at,

        analyzed=True,

    )

@router.post("/telegram", response_model=MessageResponse)

def telegram_incoming(body: TelegramWebhookIn, db: Session = Depends(get_db)) -> MessageResponse:

    """

    Приём сообщения из Telegram (демо JSON или прокси Bot API update).

    """

    _check_secret(body.secret, settings.telegram_webhook_secret)

    text = body.text

    tg_user_id = body.telegram_user_id

    username = body.username

    chat_id = body.chat_id

    if body.update:

        msg = body.update.get("message") or body.update.get("edited_message")

        if msg:

            text = msg.get("text") or text

            frm = msg.get("from") or {}

            tg_user_id = str(frm.get("id")) if frm.get("id") else tg_user_id

            username = username or frm.get("username")

            chat_id = str(msg.get("chat", {}).get("id")) if msg.get("chat") else chat_id

    if not text or not text.strip():
        raise HTTPException(status_code=400, detail="Пустой текст сообщения")

    require_scammer_sender(db, username, channel_label="telegram")

    payload = MessageIngest(
        username=username,
        channel=MessageChannel.telegram,

        external_id=f"tg-{chat_id}-{tg_user_id}",

        body=text.strip(),

        metadata={

            "telegram_user_id": tg_user_id,

            "chat_id": chat_id,

            "telegram_username": username,

        },

        raw_payload=body.model_dump(),

        impersonates_username=body.impersonates_username,

    )

    message = ingest_message(db, payload)

    process_incoming_message(db, message)

    return MessageResponse(

        id=message.id,

        channel=message.channel,

        body=message.body,

        created_at=message.created_at,

        analyzed=True,

    )
