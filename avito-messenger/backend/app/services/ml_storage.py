import time
import uuid
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.db.models import (
    AnalysisRun,
    Message,
    MessageFeatures,
    StyleProfile,
    StyleProfileSnapshot,
    TrainingLabel,
    TrainingLabelType,
    User,
    UserRole,
)

def save_analysis_run(
    db: Session,
    message_id: uuid.UUID,
    *,
    model_name: str,
    model_version: str | None,
    analysis_source: str,
    request_payload: dict,
    response_payload: dict | None,
    risk_score: float | None,
    inference_ms: int | None,
    success: bool = True,
    error_message: str | None = None,
) -> AnalysisRun:
    run = AnalysisRun(
        id=uuid.uuid4(),
        message_id=message_id,
        model_name=model_name,
        model_version=model_version,
        analysis_source=analysis_source,
        request_payload=request_payload,
        response_payload=response_payload,
        risk_score=risk_score,
        inference_ms=inference_ms,
        success=success,
        error_message=error_message,
    )
    db.add(run)
    return run

def apply_features_from_analysis(
    db: Session,
    message: Message,
    features: MessageFeatures,
    *,
    model_name: str,
    model_version: str | None,
    layer_hits: dict | None,
    raw_response: dict | None,
    embedding: list | None,
    inference_ms: int | None,
) -> None:
    features.layer_hits = layer_hits
    features.model_name = model_name
    features.model_version = model_version
    features.raw_ai_response = raw_response
    features.embedding = embedding
    features.inference_ms = inference_ms

def auto_training_label(db: Session, message: Message, sender: User | None, risk_score: float) -> None:
    """Эвристическая разметка до ручной правки экспертом."""
    existing = db.query(TrainingLabel).filter(TrainingLabel.message_id == message.id).first()
    if existing and existing.labeled_by not in ("auto", "auto_role"):
        return

    label = TrainingLabelType.unknown
    confidence = 0.5
    notes = "Авто-разметка gateway"

    if sender:
        if sender.role == UserRole.scammer:
            label = TrainingLabelType.impersonation if risk_score >= 0.5 else TrainingLabelType.suspicious
            confidence = 0.85
            notes = "Роль scammer в демо-данных"
        elif sender.role == UserRole.user and risk_score < 0.3:
            label = TrainingLabelType.legit
            confidence = 0.7
            notes = "Обычный пользователь, низкий risk"

    if existing:
        existing.label = label
        existing.confidence = confidence
        existing.notes = notes
        existing.labeled_by = "auto_role"
    else:
        db.add(
            TrainingLabel(
                id=uuid.uuid4(),
                message_id=message.id,
                label=label,
                confidence=confidence,
                labeled_by="auto_role",
                notes=notes,
                is_gold=False,
            )
        )

def snapshot_style_profile(db: Session, user_id: uuid.UUID, reason: str = "message_ingest") -> None:
    profile = db.query(StyleProfile).filter(StyleProfile.user_id == user_id).first()
    if not profile:
        return
    db.add(
        StyleProfileSnapshot(
            id=uuid.uuid4(),
            user_id=user_id,
            reference_vector=profile.reference_vector,
            traits=profile.traits,
            sample_count=profile.sample_count,
            snapshot_reason=reason,
        )
    )

class AnalysisTimer:
    def __enter__(self):
        self._start = time.perf_counter()
        return self

    def __exit__(self, *args):
        self.elapsed_ms = int((time.perf_counter() - self._start) * 1000)
