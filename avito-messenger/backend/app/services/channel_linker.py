from __future__ import annotations

import re
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from app.db.models import Alert, AlertSeverity, ChannelLink, Message, MessageChannel, User

_LINK_KEYWORDS = (
    "срочно",
    "перевод",
    "ceo",
    "алексей",
    "пароль",
    "конфиденциально",
    "bitcoin",
    "крипт",
    "подтверди",
    "счёт",
    "счет",
    "реквизит",
)

def _normalize(text: str) -> set[str]:
    words = re.findall(r"[a-zа-яё0-9]+", text.lower())
    return {w for w in words if len(w) > 2}

def _text_similarity(a: str, b: str) -> float:
    wa, wb = _normalize(a), _normalize(b)
    if not wa or not wb:
        return 0.0
    inter = len(wa & wb)
    return inter / max(len(wa), len(wb))

def _keyword_boost(text: str) -> float:
    low = text.lower()
    hits = sum(1 for k in _LINK_KEYWORDS if k in low)
    return min(0.35, hits * 0.08)

def _find_candidates(db: Session, message: Message, *, window_hours: int = 4) -> list[Message]:
    since = datetime.now(UTC) - timedelta(hours=window_hours)
    other_channels = [c for c in MessageChannel if c != message.channel]
    filters = [
        Message.id != message.id,
        Message.channel.in_(other_channels),
        Message.created_at >= since,
    ]
    if message.sender_id:
        filters.append(
            (Message.sender_id == message.sender_id)
            | (Message.impersonated_user_id == message.impersonated_user_id)
            | (Message.impersonated_user_id.isnot(None))
        )
    return (
        db.query(Message)
        .filter(*filters)
        .order_by(Message.created_at.desc())
        .limit(50)
        .all()
    )

def _score_pair(msg_a: Message, msg_b: Message) -> tuple[float, str]:
    sim = _text_similarity(msg_a.body, msg_b.body)
    boost = _keyword_boost(msg_a.body) + _keyword_boost(msg_b.body)
    score = min(1.0, sim + boost)

    reasons: list[str] = []
    if sim >= 0.25:
        reasons.append(f"похожий текст ({sim:.0%})")
    if boost > 0:
        reasons.append("ключевые слова атаки")
    if msg_a.impersonated_user_id and msg_a.impersonated_user_id == msg_b.impersonated_user_id:
        score = min(1.0, score + 0.25)
        reasons.append("одна цель импersonation")
    if msg_a.sender_id and msg_a.sender_id == msg_b.sender_id:
        score = min(1.0, score + 0.15)
        reasons.append("один отправитель")

    reason_ru = "; ".join(reasons) if reasons else "временная близость и контекст"
    return score, reason_ru

def try_link_message(db: Session, message: Message, *, min_score: float = 0.45) -> ChannelLink | None:
    """Попытаться связать новое сообщение с недавними в других каналах."""
    for other in _find_candidates(db, message):
        existing = (
            db.query(ChannelLink)
            .filter(
                ((ChannelLink.message_id_a == message.id) & (ChannelLink.message_id_b == other.id))
                | ((ChannelLink.message_id_a == other.id) & (ChannelLink.message_id_b == message.id))
            )
            .first()
        )
        if existing:
            continue

        score, reason_ru = _score_pair(message, other)
        if score < min_score:
            continue

        link = ChannelLink(
            id=uuid.uuid4(),
            message_id_a=message.id,
            message_id_b=other.id,
            link_score=score,
            reason_ru=reason_ru,
        )
        db.add(link)
        db.flush()
        _maybe_cross_channel_alert(db, message, other, link)
        return link
    return None

def _maybe_cross_channel_alert(db: Session, msg_a: Message, msg_b: Message, link: ChannelLink) -> None:
    if link.link_score < 0.55:
        return

    channels = {msg_a.channel.value, msg_b.channel.value}
    ch_label = " ↔ ".join(sorted(channels))
    explanation = (
        f"Обнаружена связь между каналами ({ch_label}). {link.reason_ru}. "
        f"Сообщение 1 ({msg_a.channel.value}): «{msg_a.body[:120]}…» "
        f"Сообщение 2 ({msg_b.channel.value}): «{msg_b.body[:120]}…»"
    )
    from app.services.messages import get_admin_user_ids

    alert = Alert(
        severity=AlertSeverity.high if link.link_score >= 0.7 else AlertSeverity.medium,
        alert_type="cross_channel",
        title_ru="Кросс-канальная атака",
        explanation_ru=explanation,
        related_message_ids=[msg_a.id, msg_b.id],
        target_user_ids=get_admin_user_ids(db),
        delivered=False,
    )
    db.add(alert)
    db.flush()

    from app.services.alert_delivery import deliver_alert

    sender = db.get(User, msg_a.sender_id) if msg_a.sender_id else None
    deliver_alert(db, alert, sender)
