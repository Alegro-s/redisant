from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.db.models import StyleProfile, User
from app.services.detection.l1_stylometry import features as style_features

def maybe_update_style_profile(db: Session, user: User, text: str, risk_score: float | None) -> None:
    if not text or len(text.strip()) < 3:
        return
    if risk_score is not None and risk_score >= 0.35:
        return
    profile = db.query(StyleProfile).filter(StyleProfile.user_id == user.id).first()
    if not profile:
        profile = StyleProfile(id=uuid.uuid4(), user_id=user.id, sample_count=0)
        db.add(profile)
    feat = style_features(text)
    traits = dict(profile.traits or {})
    prev_count = int(profile.sample_count or 0)
    alpha = min(0.25, 1.0 / max(prev_count + 1, 5))
    ref = dict(profile.reference_vector or feat)
    for key, val in feat.items():
        ref[key] = float(ref.get(key, val)) * (1 - alpha) + float(val) * alpha
    traits["short_messages"] = ref.get("avg_word_len", 5) < 5.5
    traits["uses_exclamation"] = ref.get("exclamation_rate", 0) > 0.05
    profile.reference_vector = ref
    profile.traits = traits
    profile.sample_count = prev_count + 1
    db.add(profile)
