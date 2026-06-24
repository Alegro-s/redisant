from __future__ import annotations

from pathlib import Path

import numpy as np

_MODEL_PATH = Path(__file__).resolve().parents[3] / "data" / "models" / "risk_fusion_v1.joblib"
_clf = None

def _load():
    global _clf
    if _clf is not None:
        return _clf
    if not _MODEL_PATH.is_file():
        _clf = False
        return _clf
    try:
        import joblib

        _clf = joblib.load(_MODEL_PATH)
    except Exception:
        _clf = False
    return _clf

def _vector(layer_scores: dict, layer_hits: dict, extras: dict) -> np.ndarray:
    spoof = float(extras.get("spoof_score", 0))
    speaker = float(extras.get("speaker_match", 1.0))
    return np.array(
        [
            [
                float(layer_scores.get("l1", 0)),
                float(layer_scores.get("l2", 0)),
                float(layer_scores.get("l3", 0)),
                float(layer_scores.get("l4", 0)),
                float(layer_scores.get("l5", 0)),
                float(layer_scores.get("l6", 0)),
                float(layer_hits.get("l1_stylometry", 0)),
                float(layer_hits.get("l2_embeddings", 0)),
                float(layer_hits.get("l3_metadata", 0)),
                float(layer_hits.get("l4_ai_indicator", 0)),
                float(layer_hits.get("l5_intent", 0)),
                float(layer_hits.get("l6_voice", 0)),
                spoof,
                speaker,
            ]
        ],
        dtype=float,
    )

def fuse_risk(
    layer_scores: dict,
    layer_hits: dict,
    *,
    heuristic_risk: float,
    extras: dict | None = None,
) -> float:
    extras = extras or {}
    model = _load()
    if model and model is not False:
        try:
            pipe = model.get("pipeline") if isinstance(model, dict) else model
            if pipe is not None:
                proba = pipe.predict_proba(_vector(layer_scores, layer_hits, extras))[0]
                classes = list(pipe.classes_)
                if "phishing" in classes:
                    idx = classes.index("phishing")
                    return float(min(max(proba[idx], 0.0), 1.0))
                return float(min(max(max(proba), 0.0), 1.0))
        except Exception:
            pass

    weights = {
        "l1": 0.18,
        "l2": 0.17,
        "l3": 0.14,
        "l4": 0.14,
        "l5": 0.17,
        "l6": 0.12,
        "behavior": 0.04,
        "intent_ent": 0.04,
    }
    risk = sum(float(layer_scores.get(k, 0)) * w for k, w in weights.items())
    hit_count = sum(1 for v in layer_hits.values() if v)
    if hit_count >= 2:
        risk += 0.06 * (hit_count - 1)
    if hit_count >= 4:
        risk += 0.05
    if extras.get("spoof_score", 0) >= 0.55:
        risk += 0.12
    if extras.get("speaker_match", 1.0) < 0.72:
        risk += 0.1
    blended = 0.65 * risk + 0.35 * heuristic_risk
    return float(min(max(blended, 0.0), 1.0))
