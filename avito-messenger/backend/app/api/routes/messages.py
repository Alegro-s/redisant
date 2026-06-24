from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.models import Message
from app.db.session import get_db
from app.schemas.message import MessageIngest, MessageResponse
from app.services.ingest_pipeline import process_incoming_message
from app.services.messages import ingest_message

router = APIRouter(prefix="/messages", tags=["messages"])

@router.post("/ingest", response_model=MessageResponse)
def post_ingest(payload: MessageIngest, db: Session = Depends(get_db)) -> MessageResponse:
    message = ingest_message(db, payload)
    process_incoming_message(db, message)
    return MessageResponse(
        id=message.id,
        channel=message.channel,
        body=message.body,
        created_at=message.created_at,
        analyzed=True,
    )

@router.get("/{message_id}", response_model=MessageResponse)
def get_message(message_id: UUID, db: Session = Depends(get_db)) -> MessageResponse:
    message = db.get(Message, message_id)
    if not message:
        raise HTTPException(status_code=404, detail="Сообщение не найдено")
    return MessageResponse(
        id=message.id,
        channel=message.channel,
        body=message.body,
        created_at=message.created_at,
        analyzed=message.features is not None,
    )
