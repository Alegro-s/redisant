from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.models import Alert, AlertSeverity, Message, MessageFeatures, StyleProfile, User, UserMlProfile, UserRole
from app.services.detection.l1_stylometry import FEATURE_KEYS
from app.services.user_ml import ensure_user_ml_profile

STYLE_ZONE_META: tuple[tuple[str, str, str], ...] = (
    ("length", "Длина", "avg_word_len"),
    ("emotion", "Эмоции", "exclamation_rate"),
    ("questions", "Вопросы", "question_rate"),
    ("register", "Регистр", "uppercase_rate"),
    ("politeness", "Вежливость", "polite_rate"),
    ("consistency", "Стабильность", "style_similarity"),
)

_ANOMALY_THRESHOLD = 0.28
_SUSTAINED_STREAK = 4
_ALERT_COOLDOWN = timedelta(hours=1)


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def _norm_length(avg_word_len: float) -> float:
    return _clamp01((avg_word_len - 3.0) / 9.0)


def _norm_rate(rate: float, cap: float) -> float:
    return _clamp01(rate / cap) if cap > 0 else 0.0


def _message_rows(db: Session, user_id: uuid.UUID, *, limit: int = 48) -> list[tuple[Message, MessageFeatures | None]]:
    rows = (
        db.query(Message, MessageFeatures)
        .outerjoin(MessageFeatures, MessageFeatures.message_id == Message.id)
        .filter(Message.sender_id == user_id)
        .order_by(Message.created_at.asc())
        .limit(limit)
        .all()
    )
    return list(rows)


def build_communication_series(db: Session, user_id: uuid.UUID, *, limit: int = 48) -> dict:
    rows = _message_rows(db, user_id, limit=limit)
    baseline = 18.0
    points: list[dict] = []

    for msg, feat in rows:
        risk = float(feat.risk_score or 0) if feat else 0.0
        style_sim = float(feat.style_similarity) if feat and feat.style_similarity is not None else 0.82
        anomaly = max(risk, 1.0 - style_sim)
        is_anomaly = anomaly >= _ANOMALY_THRESHOLD

        if not is_anomaly:
            baseline = min(88.0, baseline + 1.8)

        spike = 0.0
        if is_anomaly:
            spike = min(38.0, 12.0 + anomaly * 42.0)

        value = min(100.0, baseline + spike)
        created = msg.created_at.astimezone(UTC) if msg.created_at else None
        points.append(
            {
                "time": created.strftime("%d.%m %H:%M") if created else "",
                "value": round(value, 1),
                "baseline": round(baseline, 1),
                "spike": round(spike, 1),
                "anomaly": is_anomaly,
                "risk": int(risk * 100),
            }
        )

    elevated_streak = 0
    for point in reversed(points):
        if point["spike"] > 8 or point["anomaly"]:
            elevated_streak += 1
        else:
            break

    sustained = elevated_streak >= _SUSTAINED_STREAK
    label = "Стабильное общение"
    if sustained:
        label = "Длительное отклонение от нормы"
    elif elevated_streak > 0:
        label = "Кратковременные всплески"
    elif len(points) < 2:
        label = "Недостаточно данных"

    return {
        "points": points,
        "elevated_streak": elevated_streak,
        "sustained": sustained,
        "label": label,
    }


def build_style_zones(db: Session, user_id: uuid.UUID) -> dict:
    style = db.query(StyleProfile).filter(StyleProfile.user_id == user_id).first()
    ref = dict(style.reference_vector or {}) if style else {}

    avg_sim_row = (
        db.query(func.avg(MessageFeatures.style_similarity))
        .join(Message, Message.id == MessageFeatures.message_id)
        .filter(Message.sender_id == user_id, MessageFeatures.style_similarity.isnot(None))
        .scalar()
    )
    avg_sim = float(avg_sim_row) if avg_sim_row is not None else 0.75

    raw = {
        "avg_word_len": float(ref.get("avg_word_len", 5.5)),
        "exclamation_rate": float(ref.get("exclamation_rate", 0.02)),
        "question_rate": float(ref.get("question_rate", 0.03)),
        "uppercase_rate": float(ref.get("uppercase_rate", 0.04)),
        "polite_rate": float(ref.get("polite_rate", 0.02)),
        "style_similarity": avg_sim,
    }

    norms = {
        "avg_word_len": _norm_length(raw["avg_word_len"]),
        "exclamation_rate": _norm_rate(raw["exclamation_rate"], 0.12),
        "question_rate": _norm_rate(raw["question_rate"], 0.1),
        "uppercase_rate": _norm_rate(raw["uppercase_rate"], 0.25),
        "polite_rate": _norm_rate(raw["polite_rate"], 0.15),
        "style_similarity": _clamp01(avg_sim),
    }

    zones = []
    for zone_id, label, key in STYLE_ZONE_META:
        zones.append(
            {
                "id": zone_id,
                "label": label,
                "value": round(norms.get(key, 0.0), 3),
                "raw": round(raw.get(key, 0.0), 4) if key != "style_similarity" else round(avg_sim, 3),
            }
        )

    sample_count = int(style.sample_count or 0) if style else 0
    learning_pct = min(100, int(sample_count * 4))
    return {
        "zones": zones,
        "sample_count": sample_count,
        "learning_pct": learning_pct,
        "feature_keys": list(FEATURE_KEYS),
    }


def _sustained_threat_boost(series: dict) -> int:
    if not series.get("sustained"):
        return 0
    streak = int(series.get("elevated_streak") or 0)
    return min(35, 18 + streak * 3)


def maybe_alert_sustained_drift(db: Session, user_id: uuid.UUID | None) -> Alert | None:
    if not user_id:
        return None

    user = db.get(User, user_id)
    if not user or user.role in (UserRole.admin, UserRole.super_admin):
        return None

    series = build_communication_series(db, user_id)
    if not series.get("sustained"):
        ml = db.query(UserMlProfile).filter(UserMlProfile.user_id == user_id).first()
        if ml and ml.model_state and isinstance(ml.model_state, dict):
            state = dict(ml.model_state)
            drift = dict(state.get("comm_drift") or {})
            drift["elevated_streak"] = series.get("elevated_streak", 0)
            drift["sustained"] = False
            state["comm_drift"] = drift
            ml.model_state = state
            db.add(ml)
        return None

    ml = ensure_user_ml_profile(db, user_id)
    state = dict(ml.model_state or {})
    drift = dict(state.get("comm_drift") or {})
    now = datetime.now(UTC)

    last_alert_raw = drift.get("last_alert_at")
    if last_alert_raw:
        try:
            last_alert = datetime.fromisoformat(str(last_alert_raw).replace("Z", "+00:00"))
            if now - last_alert < _ALERT_COOLDOWN:
                drift["elevated_streak"] = series.get("elevated_streak", 0)
                drift["sustained"] = True
                state["comm_drift"] = drift
                ml.model_state = state
                db.add(ml)
                return None
        except ValueError:
            pass

    streak = int(series.get("elevated_streak") or 0)
    boost = _sustained_threat_boost(series)
    title = "Длительное отклонение стиля общения"
    explanation = (
        f"У пользователя {user.display_name} (@{user.username}) график общения "
        f"удерживается выше нормы уже {streak} сообщений подряд. "
        f"Рекомендуется повысить уровень риска (+{boost}%) и проверить последние диалоги."
    )

    alert = Alert(
        id=uuid.uuid4(),
        severity=AlertSeverity.high if boost >= 28 else AlertSeverity.medium,
        alert_type="style_anomaly",
        title_ru=title,
        explanation_ru=explanation,
        related_message_ids=[],
        target_user_ids=[],
        delivered=False,
    )
    db.add(alert)
    db.flush()

    from app.services.telegram_bot import notify_superadmin_analyst_alert

    notify_superadmin_analyst_alert(db, alert, sender_name=user.display_name)

    drift["last_alert_at"] = now.isoformat()
    drift["elevated_streak"] = streak
    drift["sustained"] = True
    drift["threat_boost"] = boost
    state["comm_drift"] = drift
    ml.model_state = state
    db.add(ml)
    return alert


def panel_communication_payload(db: Session, user: User) -> dict:
    series = build_communication_series(db, user.id)
    zones = build_style_zones(db, user.id)
    boost = _sustained_threat_boost(series)
    return {
        "graph": series,
        "style_zones": zones,
        "threat_boost": boost,
    }
