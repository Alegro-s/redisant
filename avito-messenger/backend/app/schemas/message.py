from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.db.models import MessageChannel

class MessageIngest(BaseModel):
    username: str | None = Field(None, description="Sender username from our users table")
    sender_id: UUID | None = None
    channel: MessageChannel = MessageChannel.mattermost
    external_id: str | None = None
    body: str
    metadata: dict | None = None
    raw_payload: dict | None = None
    impersonates_username: str | None = Field(
        None, description="Под кого выдаёт себя отправитель (например ceo)"
    )

class MessageResponse(BaseModel):
    id: UUID
    channel: MessageChannel
    body: str
    created_at: datetime
    analyzed: bool = False

    model_config = {"from_attributes": True}
