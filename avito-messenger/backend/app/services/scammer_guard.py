from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.db.models import User, UserRole

def require_scammer_sender(db: Session, username: str | None, *, channel_label: str = "сообщение") -> User:
    if not username:
        raise HTTPException(
            status_code=400,
            detail=f"Поле username обязательно — {channel_label} принимается только от scammer (scammer1–3)",
        )
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"Пользователь {username} не найден")
    if user.role != UserRole.scammer:
        raise HTTPException(
            status_code=403,
            detail=f"Отклонено: {channel_label} может отправлять только пользователь с ролью scammer",
        )
    if user.is_blocked:
        raise HTTPException(
            status_code=403,
            detail=f"Пользователь {username} заблокирован: {user.block_reason or 'без причины'}",
        )
    return user
