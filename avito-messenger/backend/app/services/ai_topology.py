from __future__ import annotations

from app.config import get_settings
from app.services.ai_client import ai_service_online
from app.services.inference_gateway import EXPECTED_MS, gateway_configured, gateway_status
from app.services.secure_bundle import get_inference_endpoints

def _node(
    nid: str,
    label: str,
    kind: str,
    *,
    status: str,
    latency_ms: int | None = None,
    note: str = "",
    optional: bool = False,
) -> dict:
    return {
        "id": nid,
        "label": label,
        "kind": kind,
        "status": status,
        "latency_ms": latency_ms,
        "note": note,
        "optional": optional,
    }

def _edge(src: str, dst: str, *, label: str = "", optional: bool = False, active: bool = True) -> dict:
    return {"from": src, "to": dst, "label": label, "optional": optional, "active": active}

def resolve_ai_mode(*, gw_cfg: bool, gw_on: bool, core_cfg: bool, core_on: bool) -> str:
    if gw_cfg and gw_on:
        return "gateway_hybrid"
    if gw_cfg and not gw_on:
        return "local_fallback"
    if core_cfg and core_on:
        return "core_remote"
    if core_cfg:
        return "local_fallback"
    return "local_only"

def build_ai_topology(
    *,
    messenger_online: bool,
    gateway_online: bool,
    db_online: bool,
    detection_ready: bool,
    messenger_latency: int | None = None,
    gateway_latency: int | None = None,
    db_latency: int | None = None,
    gw_status=None,
) -> dict:
    settings = get_settings()
    gw = gw_status if gw_status is not None else gateway_status()
    ep = get_inference_endpoints()
    core_cfg = bool(ep.core_base)
    ai_core_cfg = bool(settings.ai_service_url and settings.ai_service_url.strip())
    ai_core_on, ai_core_lat = ai_service_online() if ai_core_cfg else (False, None)

    mode = resolve_ai_mode(
        gw_cfg=gw.configured,
        gw_on=gw.online,
        core_cfg=core_cfg or ai_core_cfg,
        core_on=ai_core_on,
    )

    local_status = "online" if detection_ready else "degraded"
    gw_node_status = "disabled"
    if gw.configured:
        gw_node_status = "online" if gw.online else "offline"

    ai_core_status = "disabled"
    if core_cfg or ai_core_cfg:
        ai_core_status = "online" if ai_core_on else "offline"

    nodes = [
        _node(
            "messenger",
            "NT Messenger",
            "client",
            status="online" if messenger_online else "offline",
            latency_ms=messenger_latency,
        ),
        _node(
            "gateway",
            "Gateway API",
            "service",
            status="online" if gateway_online else "offline",
            latency_ms=gateway_latency,
        ),
        _node(
            "local_l1l5",
            "L1–L5 локально",
            "core",
            status=local_status,
            note=f"{EXPECTED_MS['local_layers']} ms",
        ),
        _node(
            "fusion",
            "Adaptive Fusion",
            "process",
            status="online" if detection_ready else "degraded",
        ),
        _node(
            "postgres",
            "PostgreSQL",
            "db",
            status="online" if db_online else "offline",
            latency_ms=db_latency,
        ),
        _node(
            "inference_gw",
            "Private inference",
            "ai_remote",
            status=gw_node_status,
            latency_ms=gw.latency_ms,
            note=f"explain {EXPECTED_MS['gw_explain']} ms",
            optional=True,
        ),
        _node(
            "voice_core",
            "Voice L6",
            "ai_remote",
            status="online" if ep.voice_base else "disabled",
            optional=True,
        ),
        _node(
            "ai_core",
            "AI Core :8001",
            "ai_remote",
            status=ai_core_status,
            latency_ms=ai_core_lat,
            optional=True,
        ),
    ]

    gw_active = gw.configured and gw.online
    ai_core_active = (core_cfg or ai_core_cfg) and ai_core_on

    edges = [
        _edge("messenger", "gateway", label="HTTPS / REST"),
        _edge("gateway", "local_l1l5", label="ingest"),
        _edge("local_l1l5", "fusion"),
        _edge("fusion", "postgres", label="features + alerts"),
        _edge(
            "gateway",
            "inference_gw",
            label="private API",
            optional=True,
            active=gw_active,
        ),
        _edge("inference_gw", "fusion", label="verdict", optional=True, active=gw_active),
        _edge("gateway", "voice_core", label="L6", optional=True, active=bool(ep.voice_base)),
        _edge(
            "gateway",
            "ai_core",
            label="/analyze",
            optional=True,
            active=ai_core_active,
        ),
        _edge("ai_core", "fusion", optional=True, active=ai_core_active),
    ]

    return {
        "mode": mode,
        "fallback": "detection_v2",
        "nodes": nodes,
        "edges": edges,
        "ai": {
            "inference_gateway": {
                "configured": gw.configured,
                "online": gw.online,
                "host": gw.host,
                "model": gw.model,
                "latency_ms": gw.latency_ms,
                "detail": gw.detail,
                "expected_ms": EXPECTED_MS,
            },
            "ai_core": {
                "configured": core_cfg or ai_core_cfg,
                "online": ai_core_on,
                "latency_ms": ai_core_lat,
            },
            "analysis_flow": [
                "1. L1–L6 локально + fusion",
                "2. Core /analyze при AI_CORE_URL",
                "3. Private gateway при risk ≥ порога или серая зона",
                "4. PostgreSQL → алерт с cooldown",
            ],
        },
    }
