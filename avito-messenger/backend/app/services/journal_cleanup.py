from __future__ import annotations

from sqlalchemy import delete, func, update
from sqlalchemy.orm import Session

from app.db.models import (
    Alert,
    AnalysisRun,
    AuditLog,
    ChannelLink,
    ChatReadState,
    Message,
    MessageFeatures,
    TrainingLabel,
    UserMlProfile,
)

def clear_admin_journal(
    db: Session,
    *,
    include_alerts: bool = True,
    include_chat_read: bool = True,
) -> dict[str, int]:
    """Очищает данные, из которых собирается журнал админки (audit + сообщения)."""
    stats = {
        "channel_links": db.execute(delete(ChannelLink)).rowcount or 0,
        "analysis_runs": db.execute(delete(AnalysisRun)).rowcount or 0,
        "message_features": db.execute(delete(MessageFeatures)).rowcount or 0,
        "training_labels": db.execute(delete(TrainingLabel)).rowcount or 0,
        "messages": db.execute(delete(Message)).rowcount or 0,
        "audit_logs": db.execute(delete(AuditLog)).rowcount or 0,
        "alerts": 0,
        "chat_read_states": 0,
        "ml_profiles_reset": 0,
    }

    if include_alerts:
        stats["alerts"] = db.execute(delete(Alert)).rowcount or 0

    if include_chat_read:
        stats["chat_read_states"] = db.execute(delete(ChatReadState)).rowcount or 0

    stats["ml_profiles_reset"] = (
        db.execute(
            update(UserMlProfile).values(
                message_count_total=0,
                message_count_24h=0,
                mattermost_count=0,
                email_count=0,
                avg_risk_score=None,
                max_risk_score=None,
                avg_message_length=None,
                high_risk_count=0,
                last_message_at=None,
                last_analyzed_at=None,
                analysis_status="pending",
                needs_reanalysis=True,
            )
        ).rowcount
        or 0
    )

    db.commit()
    return stats
