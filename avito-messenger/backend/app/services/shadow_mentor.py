from __future__ import annotations

from datetime import UTC, datetime
import random
import re

from sqlalchemy.orm import Session

from app.db.models import Message, MessageChannel, ShadowMentorCampaign, StyleProfile, User
from app.schemas.message import MessageIngest
from app.services.detection.pipeline import run_pipeline
from app.services.ingest_pipeline import process_incoming_message
from app.services.messages import ingest_message

_PHISHING_TRIGGERS = (
    "срочно", "переведи", "перевод", "реквизит", "конфиденциально",
    "не говори", "только между нами", "asap", "wire", "urgent", "transfer",
)
_POSITIVE_RESPONSE = (
    "ок", "хорошо", "сделаю", "переведу", "отправлю", "согласен", "да",
    "ok", "sure", "will do", "done", "approved",
)

def _traits(user: User, db: Session) -> dict:
    sp = db.query(StyleProfile).filter(StyleProfile.user_id == user.id).first()
    return dict(sp.traits or {}) if sp else {}

def _invert_style_message(
    target: User,
    impersonate: User,
    traits: dict,
    *,
    rng: random.Random | None = None,
) -> tuple[str, dict]:
    """Сообщение в стиле, противоположном профилю жертвы (как на слайде CEO vs AI)."""
    rng = rng or random.Random()
    short_writer = traits.get("avg_sentence_len", 12) < 10 or traits.get("formality", 0.5) < 0.4
    polite = traits.get("politeness", 0.3) < 0.35
    no_exclaim = traits.get("exclamation_rate", 0.1) < 0.05

    imp_name = impersonate.display_name or impersonate.username
    if short_writer and polite:
        text = (
            f"Добрый день! Надеюсь, у Вас всё хорошо. "
            f"Прошу проявить понимание: необходимо срочно подготовить перевод по указанным реквизитам. "
            f"Это конфиденциальный вопрос, прошу не обсуждать с коллегами до завершения. "
            f"С уважением, {imp_name}."
        )
    elif short_writer:
        text = (
            f"Здравствуйте! К сожалению, возникла непредвиденная ситуация, "
            f"и мне потребуется ваша оперативная помощь с переводом средств сегодня до конца дня. "
            f"Детали направлю отдельным сообщением. Благодарю заранее! — {imp_name}"
        )
    elif no_exclaim:
        text = (
            f"СРОЧНО!!! Нужен перевод ASAP!!! "
            f"Ответь «OK» и жди реквизиты!!! — {imp_name}!!!"
        )
    else:
        templates = [
            f"Привет, это {imp_name}. Можешь сегодня закрыть вопрос с оплатой? Напиши «ок» — скину реквизиты.",
            f"Коллега, от {imp_name}: срочно нужен перевод на резервный счёт. Подтверди готовность.",
        ]
        text = rng.choice(templates)

    meta = {
        "target": target.username,
        "impersonate": impersonate.username,
        "inverted_traits": {
            "short_writer": short_writer,
            "low_politeness": polite,
            "no_exclamation": no_exclaim,
        },
    }
    return text, meta

def create_campaign(
    db: Session,
    *,
    target_username: str,
    impersonate_username: str,
    auto_send: bool = False,
) -> ShadowMentorCampaign:
    target = db.query(User).filter(User.username == target_username).first()
    if not target:
        raise ValueError(f"Пользователь {target_username} не найден")
    imp = db.query(User).filter(User.username == impersonate_username).first()
    if not imp:
        raise ValueError(f"Пользователь {impersonate_username} не найден")

    traits = _traits(target, db)
    text, meta = _invert_style_message(target, imp, traits)
    camp = ShadowMentorCampaign(
        target_user_id=target.id,
        impersonate_user_id=imp.id,
        message_text=text,
        status="draft",
        traits_used=meta,
    )
    db.add(camp)
    db.flush()
    if auto_send:
        send_campaign(db, camp)
    db.commit()
    db.refresh(camp)
    return camp

def send_campaign(db: Session, camp: ShadowMentorCampaign) -> Message:
    target = db.get(User, camp.target_user_id)
    imp = db.get(User, camp.impersonate_user_id) if camp.impersonate_user_id else None
    if not target or not imp:
        raise ValueError("Кампания без target/impersonate")

    msg = ingest_message(
        db,
        MessageIngest(
            username=imp.username,
            channel=MessageChannel.mattermost,
            body=camp.message_text,
            metadata={
                "shadow_mentor_campaign_id": str(camp.id),
                "channel_name": "dm",
                "dialog_with": target.username,
                "kind": "text",
                "simulation": True,
            },
        ),
    )
    process_incoming_message(db, msg)
    camp.status = "sent"
    camp.sent_at = datetime.now(UTC)
    db.commit()
    return msg

def evaluate_response(db: Session, camp: ShadowMentorCampaign, response_text: str) -> ShadowMentorCampaign:
    target = db.get(User, camp.target_user_id)
    imp = db.get(User, camp.impersonate_user_id) if camp.impersonate_user_id else None
    body = response_text.strip()
    camp.user_response = body
    camp.responded_at = datetime.now(UTC)

    low = body.lower()
    agreed = any(t in low for t in _POSITIVE_RESPONSE)
    has_trigger = any(t in low for t in _PHISHING_TRIGGERS)
    pipeline = run_pipeline(
        body,
        {
            "username": target.username if target else "",
            "impersonates_username": imp.username if imp else "",
            "shadow_mentor": True,
        },
    )
    risk = pipeline["risk_score"]
    fell = agreed or (risk >= 0.55 and not re.search(r"не буду|откаж|стоп|фишинг|подозр", low))

    camp.detection_score = risk
    camp.fell_for_it = fell
    parts = []
    if agreed:
        parts.append("сотрудник согласился выполнить просьбу")
    if has_trigger:
        parts.append("в ответе есть маркеры срочного перевода")
    if risk >= 0.5:
        parts.append(f"pipeline risk {int(risk * 100)}%")
    if not fell:
        parts.append("сотрудник проявил бдительность")
    camp.explanation_ru = (
        "Shadow Mentor: " + "; ".join(parts) + "."
        if parts
        else "Shadow Mentor: нейтральный ответ."
    )
    camp.status = "evaluated"
    db.commit()
    db.refresh(camp)
    try:
        from app.services.telegram_bot import notify_subscribers_alert
        from app.db.models import Alert, AlertSeverity

        pseudo = Alert(
            severity=AlertSeverity.high if fell else AlertSeverity.low,
            alert_type="shadow_mentor",
            title_ru="Shadow Mentor: " + ("сотрудник попался" if fell else "сотрудник бдителен"),
            explanation_ru=camp.explanation_ru or "",
            related_message_ids=[],
            target_user_ids=[],
            delivered=False,
        )
        notify_subscribers_alert(db, pseudo, target.display_name if target else None)
    except Exception:
        pass
    return camp

def list_campaigns(db: Session, limit: int = 50) -> list[ShadowMentorCampaign]:
    return (
        db.query(ShadowMentorCampaign)
        .order_by(ShadowMentorCampaign.created_at.desc())
        .limit(limit)
        .all()
    )
