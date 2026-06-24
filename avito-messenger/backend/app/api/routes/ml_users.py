import json
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.services.admin_auth import require_admin_key
from app.services.user_ml import (
    build_user_corpus,
    get_user_ml_summary,
    list_users_for_ml,
    mark_user_analyzed,
    refresh_user_ml_profile,
)
from app.db.models import User

router = APIRouter(prefix="/api/ml/users", tags=["ml-per-user"], dependencies=[Depends(require_admin_key)])

class UserProfileUpdate(BaseModel):
    """Ответ внешнего ИИ после анализа пользователя."""

    model_state: dict | None = None
    reference_vector: dict | None = None
    traits: dict | None = None
    analysis_status: str = Field(default="ready", pattern="^(ready|error|training)$")

@router.get("")
def list_ml_users(
    only_needs_reanalysis: bool = Query(False),
    limit: int = Query(100, le=500),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
) -> dict:
    items = list_users_for_ml(db, only_needs_reanalysis=only_needs_reanalysis, limit=limit, offset=offset)
    return {"count": len(items), "limit": limit, "offset": offset, "items": items}

@router.get("/{username}")
def get_user_bundle(
    username: str,
    message_limit: int = Query(500, le=2000),
    db: Session = Depends(get_db),
) -> dict:
    bundle = build_user_corpus(db, username, limit=message_limit)
    if not bundle:
        raise HTTPException(status_code=404, detail=f"Пользователь {username} не найден")
    return bundle

@router.get("/{username}/summary")
def get_user_summary(username: str, db: Session = Depends(get_db)) -> dict:
    summary = get_user_ml_summary(db, username)
    if not summary:
        raise HTTPException(status_code=404, detail=f"Пользователь {username} не найден")
    return summary

@router.post("/{username}/refresh")
def refresh_user_stats(username: str, db: Session = Depends(get_db)) -> dict:
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"Пользователь {username} не найден")
    profile = refresh_user_ml_profile(db, user.id)
    db.commit()
    return {"ok": True, "username": username, "needs_reanalysis": profile.needs_reanalysis}

@router.post("/{username}/profile")
def update_user_profile_from_ai(
    username: str,
    body: UserProfileUpdate,
    db: Session = Depends(get_db),
) -> dict:
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(status_code=404, detail=f"Пользователь {username} не найден")
    profile = mark_user_analyzed(
        db,
        user.id,
        model_state=body.model_state,
        reference_vector=body.reference_vector,
        traits=body.traits,
        analysis_status=body.analysis_status,
    )
    db.commit()
    return {
        "ok": True,
        "username": username,
        "profile_version": profile.profile_version,
        "analysis_status": profile.analysis_status,
    }

@router.post("/{username}/export")
def export_user_corpus(username: str, db: Session = Depends(get_db)) -> dict:
    bundle = build_user_corpus(db, username)
    if not bundle:
        raise HTTPException(status_code=404, detail=f"Пользователь {username} не найден")

    base = Path("/app/data/training/users") if Path("/app/data/training/users").exists() else Path("data/training/users")
    base.mkdir(parents=True, exist_ok=True)
    path = base / f"{username}.json"
    path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    return {"ok": True, "username": username, "file_path": str(path), "message_count": bundle["message_count"]}

@router.get("/{username}/export/{filename}")
def download_user_export(username: str, filename: str):
    if filename != f"{username}.json" or ".." in filename:
        raise HTTPException(status_code=400, detail="Неверное имя файла")
    base = Path("/app/data/training/users") if Path("/app/data/training/users").exists() else Path("data/training/users")
    path = base / filename
    if not path.exists():
        raise HTTPException(status_code=404, detail="Файл не найден")
    return FileResponse(path, media_type="application/json", filename=filename)
