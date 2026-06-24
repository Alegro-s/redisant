from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.services.admin_auth import admin_key_from_header, require_admin_key
from app.services.admin_message_unlock import try_unlock, unlock_ttl_remaining
from app.services.dashboard import build_dashboard
from app.services.journal_cleanup import clear_admin_journal
from app.services.system_test import run_system_test
from app.services.user_actions import block_user as do_block
from app.services.user_actions import unblock_user as do_unblock
from app.services.user_panel import build_user_panel, purge_user_data

router = APIRouter(prefix="/api", tags=["admin-panel"], dependencies=[Depends(require_admin_key)])

class BlockBody(BaseModel):
    reason: str = "Подозрительная активность"

@router.get("/dashboard")
def get_dashboard(db: Session = Depends(get_db)) -> dict:
    return build_dashboard(db)

@router.get("/system/test")
def system_test(db: Session = Depends(get_db)) -> dict:
    return run_system_test(db)

@router.post("/users/{user_id}/block")
def block_user_endpoint(
    user_id: str,
    body: BlockBody,
    db: Session = Depends(get_db),
) -> dict:
    user = do_block(db, user_id, body.reason)
    return {
        "ok": True,
        "username": user.username,
        "status": "blocked",
        "is_blocked": user.is_blocked,
        "block_reason": user.block_reason,
    }

@router.post("/users/{user_id}/unblock")
def unblock_user_endpoint(user_id: str, db: Session = Depends(get_db)) -> dict:
    user = do_unblock(db, user_id)
    return {
        "ok": True,
        "username": user.username,
        "status": "active",
        "is_blocked": user.is_blocked,
    }

class AdminUnlockBody(BaseModel):
    view_key: str = Field(..., min_length=8, max_length=256)

@router.post("/admin/messages/unlock")
def unlock_messages(body: AdminUnlockBody, admin_key: str | None = Depends(admin_key_from_header)) -> dict:
    from app.config import get_settings

    expected = (get_settings().msg_admin_view_key or "").strip()
    if not expected:
        return {"ok": False, "detail": "MSG_ADMIN_VIEW_KEY не настроен на сервере"}
    if not admin_key or not try_unlock(admin_key, body.view_key.strip(), expected):
        raise HTTPException(status_code=403, detail="Неверный ключ просмотра")
    return {"ok": True, "expires_in": unlock_ttl_remaining(admin_key)}

@router.get("/users/{username}/panel")
def get_user_panel(username: str, db: Session = Depends(get_db), admin_key: str | None = Depends(admin_key_from_header)) -> dict:
    return build_user_panel(db, username, admin_api_key=admin_key)

@router.delete("/users/{username}/data")
def delete_user_data(username: str, db: Session = Depends(get_db)) -> dict:
    return purge_user_data(db, username)

@router.post("/admin/clear-journal")
def clear_journal_endpoint(db: Session = Depends(get_db)) -> dict:
    stats = clear_admin_journal(db)
    return {"ok": True, "cleared": stats}

@router.post("/admin/process-pending")
def process_pending_endpoint(
    db: Session = Depends(get_db),
    limit: int = 50,
    local_only: bool = True,
) -> dict:
    from app.services.pending_analysis import drain_pending_messages

    stats = drain_pending_messages(
        db,
        limit=max(1, min(limit, 2000)),
        local_only=local_only,
    )
    return {"ok": True, **stats}
