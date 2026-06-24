from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.routes.chat import _can_see_analyst, _secure_admin_unread
from app.config import get_settings
from app.db.models import Alert, User
from app.db.session import get_db
from app.api.routes.chat import _auth_user

router = APIRouter(prefix="/chat", tags=["chat-shield"])

class ShieldAlertOut(BaseModel):
    id: str
    created_at: datetime
    severity: str
    title: str
    text: str

class ShieldStatusOut(BaseModel):
    ok: bool
    protection_active: bool
    api_ok: bool
    ai_core_configured: bool
    lm_studio_configured: bool
    email_verified: bool
    unread_security: int = 0
    recent_alerts: list[ShieldAlertOut] = []

@router.get("/shield/status", response_model=ShieldStatusOut)
def shield_status(user: User = Depends(_auth_user), db: Session = Depends(get_db)) -> ShieldStatusOut:
    settings = get_settings()
    alerts = db.query(Alert).order_by(Alert.created_at.desc()).limit(8).all()
    recent = [
        ShieldAlertOut(
            id=str(a.id),
            created_at=a.created_at or datetime.now(UTC),
            severity=a.severity.value if hasattr(a.severity, "value") else str(a.severity),
            title=a.title_ru,
            text=a.explanation_ru,
        )
        for a in alerts
    ]
    unread = _secure_admin_unread(db, user.username) if _can_see_analyst(user) else 0
    configured = bool(settings.ai_core_url or settings.lm_studio_url)
    return ShieldStatusOut(
        ok=True,
        protection_active=configured,
        api_ok=True,
        ai_core_configured=bool(settings.ai_core_url),
        lm_studio_configured=bool(settings.lm_studio_url),
        email_verified=bool(user.email_verified),
        unread_security=unread,
        recent_alerts=recent,
    )
