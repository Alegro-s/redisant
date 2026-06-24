from datetime import datetime
from uuid import UUID

from pydantic import BaseModel

from app.db.models import AlertSeverity

class AlertResponse(BaseModel):
    id: UUID
    severity: AlertSeverity
    alert_type: str
    title_ru: str
    explanation_ru: str
    created_at: datetime

    model_config = {"from_attributes": True}
