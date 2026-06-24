from dataclasses import dataclass

import httpx

from app.config import get_settings

@dataclass
class AIAnalysisResult:
    risk_score: float
    style_similarity: float | None
    ai_score: float | None
    metadata_anomaly_score: float | None
    explanation_ru: str
    title_ru: str
    alert_type: str
    feature_vector: dict
    layer_hits: dict[str, float]

def analyze_with_external_ai(
    text: str,
    metadata: dict | None = None,
    *,
    timeout: int | None = None,
) -> AIAnalysisResult | None:
    settings = get_settings()
    if not (settings.ai_service_url and settings.ai_service_url.strip()):
        return None

    payload = {"text": text, "metadata": metadata or {}}
    effective_timeout = timeout if timeout is not None else settings.ai_service_timeout
    try:
        with httpx.Client(timeout=effective_timeout) as client:
            res = client.post(f"{settings.ai_service_url.rstrip('/')}/analyze", json=payload)
            if res.status_code != 200:
                return None
            data = res.json()
    except (httpx.HTTPError, ValueError):
        return None

    risk = float(data.get("risk_score", 0))
    return AIAnalysisResult(
        risk_score=risk,
        style_similarity=data.get("style_similarity"),
        ai_score=data.get("ai_score"),
        metadata_anomaly_score=data.get("metadata_anomaly_score"),
        explanation_ru=data.get("explanation_ru") or "Анализ Core.",
        title_ru=data.get("title_ru") or "Подозрительное поведение",
        alert_type=data.get("alert_type") or "ai_analysis",
        feature_vector=data.get("feature_vector") or {},
        layer_hits=data.get("layer_hits") or {},
    )

def ai_service_online() -> tuple[bool, int | None]:
    settings = get_settings()
    if not (settings.ai_service_url and settings.ai_service_url.strip()):
        return False, None
    try:
        with httpx.Client(timeout=3) as client:
            res = client.get(f"{settings.ai_service_url.rstrip('/')}/health")
            return res.status_code == 200, int(res.elapsed.total_seconds() * 1000)
    except httpx.HTTPError:
        return False, None
