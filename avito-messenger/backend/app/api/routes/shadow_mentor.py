from __future__ import annotations

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.db.models import ShadowMentorCampaign, User
from app.db.session import get_db
from app.services.admin_auth import require_admin_key
from app.services.shadow_mentor import create_campaign, evaluate_response, list_campaigns, send_campaign

router = APIRouter(prefix="/api/shadow-mentor", tags=["shadow-mentor"], dependencies=[Depends(require_admin_key)])

class CampaignCreateIn(BaseModel):
    target_username: str = Field(..., min_length=1, max_length=64)
    impersonate_username: str = Field(..., min_length=1, max_length=64)
    auto_send: bool = False

class CampaignEvaluateIn(BaseModel):
    response_text: str = Field(..., min_length=1, max_length=8000)

class CampaignOut(BaseModel):
    id: UUID
    target_username: str
    impersonate_username: str | None
    message_text: str
    status: str
    user_response: str | None
    fell_for_it: bool | None
    detection_score: float | None
    explanation_ru: str | None
    created_at: datetime
    sent_at: datetime | None
    responded_at: datetime | None

def _to_out(db: Session, c: ShadowMentorCampaign) -> CampaignOut:
    target = db.get(User, c.target_user_id)
    imp = db.get(User, c.impersonate_user_id) if c.impersonate_user_id else None
    return CampaignOut(
        id=c.id,
        target_username=target.username if target else "?",
        impersonate_username=imp.username if imp else None,
        message_text=c.message_text,
        status=c.status,
        user_response=c.user_response,
        fell_for_it=c.fell_for_it,
        detection_score=c.detection_score,
        explanation_ru=c.explanation_ru,
        created_at=c.created_at,
        sent_at=c.sent_at,
        responded_at=c.responded_at,
    )

@router.get("/campaigns", response_model=list[CampaignOut])
def get_campaigns(db: Session = Depends(get_db)) -> list[CampaignOut]:
    try:
        return [_to_out(db, c) for c in list_campaigns(db)]
    except Exception:
        return []

@router.post("/campaigns", response_model=CampaignOut)
def post_campaign(body: CampaignCreateIn, db: Session = Depends(get_db)) -> CampaignOut:
    try:
        camp = create_campaign(
            db,
            target_username=body.target_username.strip(),
            impersonate_username=body.impersonate_username.strip(),
            auto_send=body.auto_send,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return _to_out(db, camp)

@router.post("/campaigns/{campaign_id}/send", response_model=CampaignOut)
def post_send(campaign_id: UUID, db: Session = Depends(get_db)) -> CampaignOut:
    camp = db.get(ShadowMentorCampaign, campaign_id)
    if not camp:
        raise HTTPException(status_code=404, detail="Кампания не найдена")
    try:
        send_campaign(db, camp)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    db.refresh(camp)
    return _to_out(db, camp)

@router.post("/campaigns/{campaign_id}/evaluate", response_model=CampaignOut)
def post_evaluate(
    campaign_id: UUID,
    body: CampaignEvaluateIn,
    db: Session = Depends(get_db),
) -> CampaignOut:
    camp = db.get(ShadowMentorCampaign, campaign_id)
    if not camp:
        raise HTTPException(status_code=404, detail="Кампания не найдена")
    camp = evaluate_response(db, camp, body.response_text)
    return _to_out(db, camp)
