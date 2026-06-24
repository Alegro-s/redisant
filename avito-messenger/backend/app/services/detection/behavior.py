from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.models import Message, MessageFeatures

def behavioral_scores(db: Session, sender_id: uuid.UUID | None, metadata: dict) -> tuple[float, int, dict]:
    if not sender_id:
        return 0.0, 0, {}

    since = datetime.now(UTC) - timedelta(days=30)
    since_24 = datetime.now(UTC) - timedelta(hours=24)

    row = (
        db.query(
            func.count(Message.id).label("total"),
            func.count(Message.id).filter(Message.created_at >= since_24).label("c24"),
            func.avg(func.length(Message.body)).label("avg_len"),
        )
        .filter(Message.sender_id == sender_id, Message.created_at >= since)
        .one()
    )

    avg_risk_row = (
        db.query(func.avg(MessageFeatures.risk_score))
        .join(Message, Message.id == MessageFeatures.message_id)
        .filter(Message.sender_id == sender_id, Message.created_at >= since)
        .scalar()
    )

    score = 0.0
    reasons: list[str] = []
    total = int(row.total or 0)
    c24 = int(row.c24 or 0)
    avg_len = float(row.avg_len or 0)
    body_len = len((metadata.get("text_preview") or metadata.get("body") or ""))

    if total >= 5 and c24 >= max(8, int(total * 0.4)):
        score += 0.22
        reasons.append("всплеск активности")

    if total >= 3 and avg_len > 20 and body_len > 0 and body_len > avg_len * 2.2:
        score += 0.2
        reasons.append("длина сообщения")

    hist_avg = float(avg_risk_row or 0)
    if hist_avg < 0.25 and metadata.get("preliminary_risk", 0) > 0.5:
        score += 0.18
        reasons.append("риск выше истории")

    hour = datetime.now(UTC).hour
    traits = metadata.get("style_traits") or {}
    typical = traits.get("typical_hours") if isinstance(traits, dict) else None
    if typical and hour not in typical:
        score += 0.15
        reasons.append("вне типичных часов")

    score = min(score, 1.0)
    hit = 1 if score >= 0.28 else 0
    return score, hit, {"behavior_score": score, "reasons": reasons}
