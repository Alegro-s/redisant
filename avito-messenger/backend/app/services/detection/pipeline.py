from __future__ import annotations

from typing import TYPE_CHECKING

from app.services.core_client import analyze_text_remote
from app.services.secure_bundle import get_inference_endpoints

if TYPE_CHECKING:
    from sqlalchemy.orm import Session
from app.services.detection.behavior import behavioral_scores
from app.services.detection.fusion import fuse_risk
from app.services.detection.intent_entities import extract_intent_entities
from app.services.detection.l1_stylometry import analyze_l1
from app.services.detection.l2_semantic import analyze_l2
from app.services.detection.l3_metadata import analyze_l3
from app.services.detection.l4_synthetic import analyze_l4
from app.services.detection.l5_intent import analyze_l5
from app.services.detection.l6_voice import analyze_l6
from app.services.detection.phishing_signals import evaluate_phishing_signals

def _merge_remote(local: dict, remote: dict | None) -> dict:
    if not remote:
        return local
    r = float(remote.get("risk_score") or 0)
    l = float(local.get("risk_score") or 0)
    if r <= l:
        return local
    out = dict(local)
    out["risk_score"] = round(max(r, l), 4)
    out["layer_hits"] = {**(local.get("layer_hits") or {}), **(remote.get("layer_hits") or {})}
    fv = dict(local.get("feature_vector") or {})
    fv["remote_core"] = True
    out["feature_vector"] = fv
    if remote.get("explanation_ru"):
        out["explanation_ru"] = remote["explanation_ru"]
    if remote.get("alert_type"):
        out["alert_type"] = remote["alert_type"]
    return out

def run_pipeline(
    text: str,
    metadata: dict | None = None,
    *,
    db: "Session | None" = None,
    voice_extras: dict | None = None,
    skip_remote: bool = False,
) -> dict:
    metadata = dict(metadata or {})
    metadata["text_preview"] = text[:500]

    style_sim, l1_hit, _ = analyze_l1(text, metadata)
    emb_sim, l2_hit, _ = analyze_l2(text, metadata)
    meta_score, l3_hit, _ = analyze_l3(text, metadata)
    ai_score, l4_hit, _ = analyze_l4(text, metadata)
    intent_score, l5_hit, _ = analyze_l5(text, metadata)
    ent_score, ent_hit, ent_extra = extract_intent_entities(text, metadata)
    voice_score, l6_hit, voice_extra = analyze_l6(voice_extras)

    behavior_score, b_hit, b_extra = (0.0, 0, {})
    if db is not None and metadata.get("sender_id"):
        behavior_score, b_hit, b_extra = behavioral_scores(db, metadata["sender_id"], metadata)

    layer_scores = {
        "l1": 1.0 - style_sim,
        "l2": 1.0 - emb_sim,
        "l3": meta_score,
        "l4": ai_score,
        "l5": max(intent_score, ent_score),
        "l6": voice_score,
        "behavior": behavior_score,
        "intent_ent": ent_score,
    }
    layer_hits = {
        "l1_stylometry": l1_hit,
        "l2_embeddings": l2_hit,
        "l3_metadata": l3_hit,
        "l4_ai_indicator": l4_hit,
        "l5_intent": 1 if (l5_hit or ent_hit) else 0,
        "l6_voice": l6_hit,
        "behavior": b_hit,
    }

    heuristic = sum(
        layer_scores[k] * w
        for k, w in (
            ("l1", 0.2),
            ("l2", 0.18),
            ("l3", 0.15),
            ("l4", 0.15),
            ("l5", 0.17),
            ("l6", 0.15),
        )
    )
    heuristic = min(max(heuristic, 0.0), 1.0)

    fusion_extras = {**voice_extra, **ent_extra}
    risk = fuse_risk(layer_scores, layer_hits, heuristic_risk=heuristic, extras=fusion_extras)

    phish = evaluate_phishing_signals(text, metadata)
    if phish["phishing_score"] > 0:
        risk = min(1.0, max(risk, phish["phishing_score"]))
        layer_scores["l5"] = max(layer_scores["l5"], phish["phishing_score"])
        if phish["layer_hit"]:
            layer_hits["l5_intent"] = 1
        fusion_extras["phishing"] = phish

    parts = []
    if l1_hit:
        parts.append("стиль")
    if l2_hit:
        parts.append("смысл")
    if l3_hit:
        parts.append("метаданные")
    if l4_hit:
        parts.append("шаблон текста")
    if layer_hits["l5_intent"]:
        parts.append("намерение")
    if l6_hit:
        parts.append("голос")
    if b_hit:
        parts.append("поведение")
    if phish.get("phishing_signals"):
        parts.append("фишинг")

    explanation = (
        phish["explanation_ru"]
        if phish.get("explanation_ru") and phish["phishing_score"] >= 0.45
        else (
            "Срабатывание: " + ", ".join(parts) + f". Риск {int(risk * 100)}%."
            if parts
            else "Отклонений не выявлено."
        )
    )

    alert_type = "style_anomaly"
    if phish.get("phishing_score", 0) >= 0.45:
        alert_type = phish.get("alert_type") or "bec_intent"
    elif l6_hit:
        alert_type = "synthetic_voice"
    elif layer_hits["l5_intent"]:
        alert_type = "bec_intent"
    elif l3_hit:
        alert_type = "metadata_anomaly"
    elif l4_hit:
        alert_type = "synthetic_text"

    title = phish.get("title_ru") if phish.get("phishing_score", 0) >= 0.45 else (
        "Высокий риск" if risk >= 0.7 else "Подозрительное сообщение"
    )

    result = {
        "risk_score": round(risk, 4),
        "style_similarity": round(style_sim, 4),
        "ai_score": round(ai_score, 4),
        "metadata_anomaly_score": round(meta_score, 4),
        "title_ru": title,
        "explanation_ru": explanation,
        "alert_type": alert_type,
        "feature_vector": {
            "source": "detection_v2",
            "model_version": "2.0.0",
            "layer_scores": layer_scores,
            "behavior": b_extra,
            "voice": voice_extra,
            "intent_entities": ent_extra,
            "phishing": phish,
        },
        "layer_hits": layer_hits,
    }

    remote = None if skip_remote else analyze_text_remote(text, metadata, timeout=min(8, get_inference_endpoints().core_timeout or 8))
    return _merge_remote(result, remote)
