from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from app.services.admin_auth import require_admin_key
from app.services.detection.pipeline import run_pipeline
from app.services.inference_gateway import (
    enrich_with_gateway,
    gateway_chat,
    gateway_configured,
    gateway_status,
    gray_zone_judge,
    list_gateway_models,
)
from app.services.secure_bundle import get_inference_endpoints

router = APIRouter(prefix="/api/lm-studio", tags=["lm-studio"], dependencies=[Depends(require_admin_key)])

class ChatTestIn(BaseModel):
    message: str = Field(min_length=1, max_length=8000)
    system: str | None = Field(default=None, max_length=4000)

class AnalyzeTestIn(BaseModel):
    text: str = Field(min_length=1, max_length=8000)
    username: str = Field(default="ceo", max_length=128)
    force_lm: bool = Field(default=True)

@router.get("/status")
def get_status() -> dict:
    st = gateway_status()
    ep = get_inference_endpoints()
    return {
        "configured": st.configured,
        "online": st.online,
        "latency_ms": st.latency_ms,
        "host": st.host,
        "model": ep.gateway_model or st.model,
        "detail": st.detail,
        "auth_configured": bool(ep.gateway_token),
        "auth_required": st.auth_required,
        "min_risk": ep.gateway_min_risk,
    }

@router.get("/models")
def get_models() -> dict:
    return list_gateway_models()

@router.post("/chat")
def post_chat(body: ChatTestIn) -> dict:
    if not gateway_configured():
        return {"ok": False, "error": "шлюз не настроен"}
    result = gateway_chat(body.message, system=body.system)
    return {
        "ok": result.ok,
        "content": result.content,
        "model": result.model,
        "inference_ms": result.inference_ms,
        "error": result.error,
    }

@router.post("/analyze")
def post_analyze(body: AnalyzeTestIn) -> dict:
    metadata = {"username": body.username, "user_name": body.username}
    local = run_pipeline(body.text, metadata)
    gw = None
    if gateway_configured():
        gw = enrich_with_gateway(body.text, metadata, local, force=body.force_lm)
        if not gw:
            gw = gray_zone_judge(body.text, metadata, local)
    source = "detection_v2"
    explanation = local.get("explanation_ru", "")
    title = local.get("title_ru", "")
    alert_type = local.get("alert_type")
    if gw:
        source = "detection_v2+gateway"
        explanation = gw.explanation_ru
        title = gw.title_ru
        alert_type = gw.alert_type
    return {
        "analysis_source": source,
        "risk_score": local.get("risk_score"),
        "risk_pct": int(float(local.get("risk_score") or 0) * 100),
        "title_ru": title,
        "explanation_ru": explanation,
        "alert_type": alert_type,
        "layer_hits": local.get("layer_hits"),
        "layer_scores": (local.get("feature_vector") or {}).get("layer_scores"),
        "lm_studio": (
            {
                "used": True,
                "model": gw.model,
                "inference_ms": gw.inference_ms,
            }
            if gw
            else {"used": False}
        ),
    }
