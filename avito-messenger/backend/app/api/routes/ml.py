from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.models import DatasetExport, Message, TrainingLabel, TrainingLabelType
from app.db.session import get_db
from app.services.admin_auth import require_admin_key
from app.services.ml_export import export_training_jsonl, get_dataset_stats

router = APIRouter(prefix="/api/ml", tags=["ml-training"], dependencies=[Depends(require_admin_key)])

class LabelBody(BaseModel):
    label: TrainingLabelType
    confidence: float | None = Field(None, ge=0, le=1)
    notes: str | None = None
    labeled_by: str = "expert"
    is_gold: bool = True

@router.get("/stats")
def ml_stats(db: Session = Depends(get_db)) -> dict:
    return get_dataset_stats(db)

@router.get("/samples")
def list_samples(
    limit: int = Query(100, le=1000),
    offset: int = Query(0, ge=0),
    has_label: bool | None = None,
    db: Session = Depends(get_db),
) -> dict:
    where = ""
    if has_label is True:
        where = "WHERE training_label IS NOT NULL"
    elif has_label is False:
        where = "WHERE training_label IS NULL"

    rows = db.execute(
        text(f"SELECT * FROM v_training_samples {where} ORDER BY message_at DESC LIMIT :lim OFFSET :off"),
        {"lim": limit, "off": offset},
    ).mappings().all()

    total = db.execute(text(f"SELECT COUNT(*) FROM v_training_samples {where}")).scalar()
    return {"total": total, "limit": limit, "offset": offset, "items": [dict(r) for r in rows]}

@router.post("/labels/{message_id}")
def set_label(message_id: UUID, body: LabelBody, db: Session = Depends(get_db)) -> dict:
    message = db.get(Message, message_id)
    if not message:
        raise HTTPException(status_code=404, detail="Сообщение не найдено")

    existing = db.query(TrainingLabel).filter(TrainingLabel.message_id == message_id).first()
    if existing:
        existing.label = body.label
        existing.confidence = body.confidence
        existing.notes = body.notes
        existing.labeled_by = body.labeled_by
        existing.is_gold = body.is_gold
    else:
        import uuid as uuid_mod

        db.add(
            TrainingLabel(
                id=uuid_mod.uuid4(),
                message_id=message_id,
                label=body.label,
                confidence=body.confidence,
                notes=body.notes,
                labeled_by=body.labeled_by,
                is_gold=body.is_gold,
            )
        )
    db.commit()
    return {"ok": True, "message_id": str(message_id), "label": body.label.value}

@router.post("/export")
def create_export(
    name: str = Query("training_export"),
    only_labeled: bool = Query(False),
    db: Session = Depends(get_db),
) -> dict:
    result = export_training_jsonl(db, name=name, only_labeled=only_labeled)
    export_record = DatasetExport(
        name=name,
        format="jsonl",
        file_path=result["file_path"],
        record_count=result["record_count"],
        filters={"only_labeled": only_labeled},
        created_by="api",
    )
    db.add(export_record)
    db.commit()
    return result

@router.get("/export/{filename}")
def download_export(filename: str):
    from pathlib import Path

    path = Path("/app/data/training") if Path("/app/data/training").exists() else Path("data/training")
    path = path / filename
    if not path.exists() or ".." in filename:
        raise HTTPException(status_code=404, detail="Файл не найден")
    return FileResponse(path, media_type="application/x-ndjson", filename=filename)
