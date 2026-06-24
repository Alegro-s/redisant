from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, text
from sqlalchemy.orm import Session

from app.db.models import Message, MessageChannel, MessageFeatures, StyleProfile, User, UserMlProfile

def ensure_user_ml_profile(db: Session, user_id: uuid.UUID) -> UserMlProfile:
    profile = db.query(UserMlProfile).filter(UserMlProfile.user_id == user_id).first()
    if profile:
        return profile
    profile = UserMlProfile(id=uuid.uuid4(), user_id=user_id)
    db.add(profile)
    db.flush()
    return profile

def refresh_user_ml_profile(db: Session, user_id: uuid.UUID) -> UserMlProfile:
    """Пересчитать агрегаты по всем сообщениям пользователя."""
    user = db.get(User, user_id)
    if not user:
        raise ValueError(f"user {user_id} not found")

    profile = ensure_user_ml_profile(db, user_id)
    since_24h = datetime.now(timezone.utc) - timedelta(hours=24)

    q = (
        db.query(
            func.count(Message.id).label("total"),
            func.count(Message.id).filter(Message.created_at >= since_24h).label("count_24h"),
            func.count(Message.id).filter(Message.channel == MessageChannel.mattermost).label("mm"),
            func.count(Message.id).filter(Message.channel == MessageChannel.email).label("email"),
            func.max(Message.created_at).label("last_at"),
            func.avg(func.length(Message.body)).label("avg_len"),
        )
        .filter(Message.sender_id == user_id)
    )
    row = q.one()

    feat_q = (
        db.query(
            func.avg(MessageFeatures.risk_score).label("avg_risk"),
            func.max(MessageFeatures.risk_score).label("max_risk"),
            func.count(MessageFeatures.id).filter(MessageFeatures.risk_score >= 0.7).label("high_risk"),
        )
        .join(Message, Message.id == MessageFeatures.message_id)
        .filter(Message.sender_id == user_id)
    )
    feat = feat_q.one()

    profile.message_count_total = row.total or 0
    profile.message_count_24h = row.count_24h or 0
    profile.mattermost_count = row.mm or 0
    profile.email_count = row.email or 0
    profile.last_message_at = row.last_at
    profile.avg_message_length = float(row.avg_len) if row.avg_len else None
    profile.avg_risk_score = float(feat.avg_risk) if feat.avg_risk is not None else None
    profile.max_risk_score = float(feat.max_risk) if feat.max_risk is not None else None
    profile.high_risk_count = feat.high_risk or 0
    profile.stylistic_features = _compute_stylistic_features(db, user_id)
    profile.needs_reanalysis = True
    if profile.analysis_status == "ready":
        profile.analysis_status = "stale"
    db.flush()
    return profile

def mark_user_analyzed(
    db: Session,
    user_id: uuid.UUID,
    *,
    model_state: dict | None = None,
    reference_vector: dict | None = None,
    traits: dict | None = None,
    analysis_status: str = "ready",
) -> UserMlProfile:
    """Вызывает внешний ИИ после обработки пользователя."""
    profile = ensure_user_ml_profile(db, user_id)
    profile.last_analyzed_at = datetime.now(timezone.utc)
    profile.needs_reanalysis = False
    profile.analysis_status = analysis_status
    profile.profile_version += 1
    if model_state is not None:
        profile.model_state = model_state

    if reference_vector is not None or traits is not None:
        style = db.query(StyleProfile).filter(StyleProfile.user_id == user_id).first()
        if not style:
            style = StyleProfile(id=uuid.uuid4(), user_id=user_id)
            db.add(style)
        if reference_vector is not None:
            style.reference_vector = reference_vector
        if traits is not None:
            style.traits = traits
        style.sample_count = profile.message_count_total

    db.flush()
    return profile

def _compute_stylistic_features(db: Session, user_id: uuid.UUID) -> dict:
    """Простые агрегаты по тексту — baseline до fine-tuned модели."""
    messages = (
        db.query(Message.body)
        .filter(Message.sender_id == user_id)
        .order_by(Message.created_at.desc())
        .limit(200)
        .all()
    )
    bodies = [m.body for m in messages if m.body]
    if not bodies:
        return {"sample_size": 0}

    lengths = [len(b) for b in bodies]
    exclam = sum(b.count("!") for b in bodies) / len(bodies)
    questions = sum(b.count("?") for b in bodies) / len(bodies)
    upper_ratio = sum(sum(1 for c in b if c.isupper()) / max(len(b), 1) for b in bodies) / len(bodies)

    return {
        "sample_size": len(bodies),
        "avg_length": sum(lengths) / len(lengths),
        "min_length": min(lengths),
        "max_length": max(lengths),
        "avg_exclamation": round(exclam, 3),
        "avg_question_marks": round(questions, 3),
        "avg_uppercase_ratio": round(upper_ratio, 4),
    }

def get_user_ml_summary(db: Session, username: str) -> dict | None:
    row = db.execute(
        text("SELECT * FROM v_user_ml_summary WHERE username = :u"),
        {"u": username},
    ).mappings().first()
    return dict(row) if row else None

def list_users_for_ml(
    db: Session,
    *,
    only_needs_reanalysis: bool = False,
    limit: int = 100,
    offset: int = 0,
) -> list[dict]:
    where = "WHERE needs_reanalysis = true" if only_needs_reanalysis else ""
    rows = db.execute(
        text(
            f"SELECT * FROM v_user_ml_summary {where} "
            "ORDER BY last_message_at DESC NULLS LAST LIMIT :lim OFFSET :off"
        ),
        {"lim": limit, "off": offset},
    ).mappings().all()
    return [dict(r) for r in rows]

def build_user_corpus(db: Session, username: str, limit: int = 500) -> dict | None:
    """Полный пакет для ИИ по одному пользователю: профиль + все сообщения с фичами."""
    summary = get_user_ml_summary(db, username)
    if not summary:
        return None

    user_id = summary["user_id"]
    messages = db.execute(
        text("""
            SELECT
                m.id AS message_id,
                m.channel::text AS channel,
                m.body,
                m.metadata,
                m.analysis_status,
                m.analysis_source,
                m.impersonated_user_id,
                m.created_at AS message_at,
                mf.risk_score,
                mf.style_similarity,
                mf.ai_score,
                mf.metadata_anomaly_score,
                mf.feature_vector,
                mf.layer_hits,
                mf.embedding,
                mf.model_name,
                mf.model_version,
                mf.raw_ai_response,
                tl.label::text AS training_label,
                tl.confidence AS label_confidence,
                tl.is_gold AS label_is_gold
            FROM messages m
            LEFT JOIN message_features mf ON mf.message_id = m.id
            LEFT JOIN training_labels tl ON tl.message_id = m.id
            WHERE m.sender_id = :uid
            ORDER BY m.created_at ASC
            LIMIT :lim
        """),
        {"uid": str(user_id), "lim": limit},
    ).mappings().all()

    return {
        "user": summary,
        "messages": [dict(m) for m in messages],
        "message_count": len(messages),
        "export_format": "user_corpus_v1",
    }
