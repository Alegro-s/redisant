from uuid import UUID

from sqlalchemy.orm import Session

from app.db.models import Message, MessageChannel, User
from app.schemas.message import MessageIngest

def resolve_sender(db: Session, payload: MessageIngest) -> User | None:
    if payload.sender_id:
        return db.get(User, payload.sender_id)
    if payload.username:
        user = db.query(User).filter(User.username == payload.username).first()
        if user:
            return user
    meta = payload.metadata or {}
    mm_uid = meta.get("user_id") or meta.get("mattermost_user_id")
    if mm_uid:
        user = db.query(User).filter(User.mattermost_user_id == str(mm_uid)).first()
        if user:
            return user
    tg_uid = meta.get("telegram_user_id")
    if tg_uid:
        user = db.query(User).filter(User.telegram_user_id == str(tg_uid)).first()
        if user:
            return user
    from_email = meta.get("from_email")
    if from_email:
        user = db.query(User).filter(User.email == from_email).first()
        if user:
            return user
    return None

def bind_external_ids(db: Session, user: User, payload: MessageIngest) -> None:
    """Сохранить ID из Mattermost/Telegram при первом сообщении."""
    meta = payload.metadata or {}
    mm_uid = meta.get("user_id") or meta.get("mattermost_user_id")
    if mm_uid and not user.mattermost_user_id:
        user.mattermost_user_id = str(mm_uid)
    tg_uid = meta.get("telegram_user_id")
    if tg_uid and not user.telegram_user_id:
        user.telegram_user_id = str(tg_uid)

def ingest_message(db: Session, payload: MessageIngest) -> Message:
    from fastapi import HTTPException

    sender = resolve_sender(db, payload)
    if sender:
        bind_external_ids(db, sender, payload)
    if sender and sender.is_blocked:
        raise HTTPException(
            status_code=403,
            detail=f"Пользователь {sender.username} заблокирован: {sender.block_reason or 'без причины'}",
        )
    impersonated_id = None
    if payload.impersonates_username:
        target = db.query(User).filter(User.username == payload.impersonates_username).first()
        if target:
            impersonated_id = target.id

    message = Message(
        sender_id=sender.id if sender else None,
        channel=payload.channel,
        external_id=payload.external_id,
        body=payload.body,
        metadata_=payload.metadata,
        raw_payload=payload.raw_payload,
        impersonated_user_id=impersonated_id,
    )
    db.add(message)
    db.commit()
    db.refresh(message)
    return message

def get_admin_user_ids(db: Session) -> list[UUID]:
    from app.db.models import UserRole

    rows = (
        db.query(User.id)
        .filter(User.role.in_([UserRole.admin, UserRole.super_admin]), User.is_active.is_(True))
        .all()
    )
    return [row[0] for row in rows]
