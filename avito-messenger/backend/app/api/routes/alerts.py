from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.db.models import Alert, User, UserRole
from app.db.session import get_db
from app.schemas.alert import AlertResponse

router = APIRouter(prefix="/alerts", tags=["alerts"])

@router.get("", response_model=list[AlertResponse])
def list_alerts(
    username: str = Query(..., description="Mattermost username to check role"),
    db: Session = Depends(get_db),
) -> list[AlertResponse]:
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    if user.role == UserRole.scammer:
        return []

    if user.role not in (UserRole.admin, UserRole.super_admin):
        return []

    alerts = (
        db.query(Alert)
        .filter(Alert.target_user_ids.contains([user.id]))
        .order_by(Alert.created_at.desc())
        .limit(50)
        .all()
    )
    return alerts

@router.get("/pending-delivery", response_model=list[AlertResponse])
def pending_delivery(db: Session = Depends(get_db)) -> list[AlertResponse]:
    """For Mattermost bot: fetch alerts not yet posted to messenger."""
    return db.query(Alert).filter(Alert.delivered.is_(False)).order_by(Alert.created_at.asc()).limit(20).all()

@router.post("/{alert_id}/delivered")
def mark_delivered(alert_id: UUID, db: Session = Depends(get_db)) -> dict:
    alert = db.get(Alert, alert_id)
    if not alert:
        raise HTTPException(status_code=404, detail="Алерт не найден")
    alert.delivered = True
    db.commit()
    return {"ok": True}
