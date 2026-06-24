from __future__ import annotations

from datetime import UTC

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db.models import Message, User
from app.services.admin_message_unlock import admin_can_view_messages
from app.services.message_crypto import admin_view_key_from_settings, open_text


def _message_display_text(m: Message, *, admin_api_key: str | None) -> str:
    meta = m.metadata_ if isinstance(m.metadata_, dict) else {}
    if meta.get("enc_v1"):
        admin_seal = meta.get("admin_seal")
        settings = get_settings()
        view_seed = (settings.msg_admin_view_key or "").strip()
        if admin_seal and view_seed and admin_api_key and admin_can_view_messages(admin_api_key):
            try:
                key = admin_view_key_from_settings(view_seed)
                return open_text(str(admin_seal), key)[:200]
            except Exception:
                return "[не удалось расшифровать]"
        return "[зашифровано — введите ключ просмотра]"
    return (m.body or "")[:200]


def build_user_panel(db: Session, username: str, *, admin_api_key: str | None = None) -> dict:
    from app.db.models import UserRole

    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")

    msgs = (
        db.query(Message)
        .filter(Message.sender_id == user.id)
        .order_by(Message.created_at.desc())
        .limit(25)
        .all()
    )
    msg_ids = [m.id for m in msgs]
    from app.db.models import MessageFeatures

    feat_map = {
        f.message_id: f
        for f in db.query(MessageFeatures).filter(MessageFeatures.message_id.in_(msg_ids)).all()
    } if msg_ids else {}
    from sqlalchemy import func

    msg_total = db.query(func.count(Message.id)).filter(Message.sender_id == user.id).scalar() or 0
    recent = []
    max_risk = 0
    for m in msgs:
        feat = feat_map.get(m.id)
        risk = int((feat.risk_score or 0) * 100) if feat else 0
        max_risk = max(max_risk, risk)
        meta = m.metadata_ or {}
        recent.append(
            {
                "time": m.created_at.astimezone(UTC).strftime("%d.%m %H:%M") if m.created_at else "",
                "text": _message_display_text(m, admin_api_key=admin_api_key),
                "risk": risk,
                "source": m.analysis_source or "—",
                "channel": meta.get("dialog_with") or str(m.channel.value),
                "encrypted": bool(meta.get("enc_v1")),
            }
        )

    from app.db.models import AuditLog

    audits = (
        db.query(AuditLog)
        .filter(AuditLog.target_username == username)
        .order_by(AuditLog.created_at.desc())
        .limit(10)
        .all()
    )
    activity = [
        {
            "time": a.created_at.astimezone(UTC).strftime("%d.%m %H:%M") if a.created_at else "",
            "type": a.action,
            "text": a.details or "",
        }
        for a in audits
    ]

    from app.db.models import UserMlProfile

    ml = db.query(UserMlProfile).filter(UserMlProfile.user_id == user.id).first()
    threat = max_risk
    if user.role in (UserRole.admin, UserRole.super_admin):
        threat = 0

    from app.services.admin_message_unlock import unlock_ttl_remaining

    messages_unlocked = bool(admin_api_key and admin_can_view_messages(admin_api_key))

    return {
        "id": user.username,
        "name": user.display_name,
        "role": _role_label(user.role),
        "status": "blocked" if user.is_blocked else "active",
        "block_reason": user.block_reason,
        "can_block": user.role not in (UserRole.admin, UserRole.super_admin),
        "threat_level": threat,
        "threat_label": _threat_label(threat),
        "messages_count": msg_total,
        "last_seen": recent[0]["time"] if recent else None,
        "voice_enrolled": bool(user.voice_enrolled_at),
        "ml": {
            "avg_risk": int((ml.avg_risk_score or 0) * 100) if ml and ml.avg_risk_score else 0,
            "high_risk_count": ml.high_risk_count if ml else 0,
        },
        "recent_messages": recent,
        "activity": activity,
        "messages_unlocked": messages_unlocked,
        "messages_unlock_ttl": unlock_ttl_remaining(admin_api_key) if admin_api_key else 0,
    }


def _role_label(role) -> str:
    from app.db.models import UserRole

    return {
        UserRole.super_admin: "супер-админ",
        UserRole.admin: "админ",
        UserRole.user: "пользователь",
        UserRole.scammer: "мошенник",
    }.get(role, role.value)


def _threat_label(score: int) -> str:
    if score >= 70:
        return "Критический"
    if score >= 45:
        return "Высокий"
    if score >= 25:
        return "Средний"
    return "Низкий"


def purge_user_data(db: Session, username: str) -> dict:
    import uuid
    from app.db.models import (
        Alert,
        AnalysisRun,
        AuditLog,
        Message,
        MessageFeatures,
        TrainingLabel,
        User,
        UserMlProfile,
        UserRole,
    )

    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    if user.role in (UserRole.admin, UserRole.super_admin):
        raise HTTPException(status_code=400, detail="Нельзя удалить данные администратора")

    from sqlalchemy import delete

    msg_ids = [m.id for m in db.query(Message.id).filter(Message.sender_id == user.id).all()]
    stats = {"messages": 0, "features": 0, "alerts": 0}
    if msg_ids:
        stats["features"] = (
            db.execute(delete(MessageFeatures).where(MessageFeatures.message_id.in_(msg_ids))).rowcount or 0
        )
        db.execute(delete(AnalysisRun).where(AnalysisRun.message_id.in_(msg_ids)))
        db.execute(delete(TrainingLabel).where(TrainingLabel.message_id.in_(msg_ids)))
        stats["messages"] = (
            db.execute(delete(Message).where(Message.sender_id == user.id)).rowcount or 0
        )

    ml = db.query(UserMlProfile).filter(UserMlProfile.user_id == user.id).first()
    if ml:
        ml.message_count_total = 0
        ml.message_count_24h = 0
        ml.high_risk_count = 0
        ml.avg_risk_score = None
        ml.max_risk_score = None
        ml.last_message_at = None

    db.add(
        AuditLog(
            id=uuid.uuid4(),
            action="user_data_purged",
            target_username=username,
            actor_username="admin_panel",
            details=f"Удалено сообщений: {stats['messages']}",
        )
    )
    db.commit()
    return {"ok": True, "purged": stats}
