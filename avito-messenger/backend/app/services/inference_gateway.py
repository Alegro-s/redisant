from __future__ import annotations

import json
import re
import time
from dataclasses import dataclass
from urllib.parse import urlparse

import httpx

from app.services.secure_bundle import InferenceEndpoints, get_inference_endpoints

EXPECTED_MS = {
    "local_layers": "5–80",
    "network_ping": "10–200",
    "gw_explain": "800–4000",
    "gw_intent": "1500–6000",
    "voice_stt": "1–4 с",
}

@dataclass
class GatewayStatus:
    configured: bool
    online: bool
    latency_ms: int | None
    model: str
    host: str
    detail: str
    auth_required: bool

@dataclass
class GatewayEnrichment:
    explanation_ru: str
    title_ru: str
    alert_type: str | None
    layer_hits: dict | None
    inference_ms: int
    model: str
    verdict: dict | None = None

@dataclass
class GatewayChatResult:
    ok: bool
    content: str
    model: str
    inference_ms: int
    error: str | None = None

def _ep() -> InferenceEndpoints:
    return get_inference_endpoints()

def gateway_configured() -> bool:
    return bool(_ep().gateway_base)

def _base_url() -> str:
    return _ep().gateway_base.rstrip("/")

def _auth_headers(token: str) -> dict[str, str]:
    if not token:
        return {}
    return {"Authorization": f"Bearer {token}"}

def _host_label(url: str) -> str:
    try:
        return urlparse(url).hostname or "node"
    except ValueError:
        return "node"

_INLINE_GATEWAY_TIMEOUT = 6
_GW_ONLINE_CACHE: tuple[float, bool] = (0.0, False)
_GW_ONLINE_CACHE_TTL = 30.0

def gateway_online_cached() -> bool:
    import time

    global _GW_ONLINE_CACHE
    if not gateway_configured():
        return False
    now = time.time()
    if now - _GW_ONLINE_CACHE[0] < _GW_ONLINE_CACHE_TTL:
        return _GW_ONLINE_CACHE[1]
    online = gateway_status().online
    _GW_ONLINE_CACHE = (now, online)
    return online

def invalidate_gateway_cache() -> None:
    global _GW_ONLINE_CACHE
    _GW_ONLINE_CACHE = (0.0, False)

def _http_client(timeout: int | None = None) -> httpx.Client:
    ep = _ep()
    return httpx.Client(timeout=timeout or ep.gateway_timeout, headers=_auth_headers(ep.gateway_token))

def gateway_status() -> GatewayStatus:
    ep = _ep()
    model = ep.gateway_model or "—"
    auth_required = bool(ep.gateway_token)
    if not ep.gateway_base:
        return GatewayStatus(False, False, None, model, "", "не настроен", auth_required)

    host = _host_label(ep.gateway_base)
    try:
        with _http_client(timeout=min(ep.gateway_timeout, 8)) as client:
            res = client.get(f"{ep.gateway_base.rstrip('/')}/v1/models")
            if res.status_code == 401:
                return GatewayStatus(True, False, None, model, host, "требуется ключ доступа", True)
            if res.status_code != 200:
                return GatewayStatus(True, False, None, model, host, f"HTTP {res.status_code}", auth_required)
            data = res.json()
            models = data.get("data") or []
            names = [m.get("id") for m in models if m.get("id")]
            detail = f"узлов: {len(models)}"
            if names:
                detail += f" ({', '.join(names[:3])}{'…' if len(names) > 3 else ''})"
            return GatewayStatus(
                True,
                True,
                int(res.elapsed.total_seconds() * 1000),
                model,
                host,
                detail,
                auth_required,
            )
    except httpx.HTTPError as exc:
        return GatewayStatus(True, False, None, model, host, str(exc)[:120], auth_required)

def list_gateway_models() -> dict:
    if not gateway_configured():
        return {"configured": False, "models": [], "error": "шлюз не настроен"}
    try:
        with _http_client(timeout=10) as client:
            res = client.get(f"{_base_url()}/v1/models")
            if res.status_code != 200:
                return {"configured": True, "models": [], "error": f"HTTP {res.status_code}"}
            data = res.json()
            models = [m.get("id") for m in (data.get("data") or []) if m.get("id")]
            return {"configured": True, "models": models, "error": None}
    except httpx.HTTPError as exc:
        return {"configured": True, "models": [], "error": str(exc)[:200]}

def gateway_chat(
    user_message: str,
    *,
    system: str | None = None,
    temperature: float = 0.3,
    max_tokens: int = 600,
) -> GatewayChatResult:
    if not gateway_configured():
        return GatewayChatResult(False, "", "", 0, "шлюз не настроен")

    ep = _ep()
    messages: list[dict[str, str]] = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": user_message})

    payload = {
        "model": ep.gateway_model,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
    }

    try:
        with _http_client() as client:
            started = time.perf_counter()
            res = client.post(f"{_base_url()}/v1/chat/completions", json=payload)
            elapsed = int((time.perf_counter() - started) * 1000)
            if res.status_code == 401:
                return GatewayChatResult(False, "", payload["model"], elapsed, "401: неверный ключ доступа")
            if res.status_code != 200:
                return GatewayChatResult(False, "", payload["model"], elapsed, f"HTTP {res.status_code}")
            body = res.json()
    except httpx.HTTPError as exc:
        return GatewayChatResult(False, "", ep.gateway_model, 0, str(exc)[:200])

    choices = body.get("choices") or []
    if not choices:
        return GatewayChatResult(False, "", payload["model"], elapsed, "пустой ответ")
    content = (choices[0].get("message") or {}).get("content") or ""
    return GatewayChatResult(True, content.strip(), payload["model"], elapsed)

def _extract_json_block(text: str) -> dict | None:
    text = text.strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    m = re.search(r"\{[\s\S]*\}", text)
    if not m:
        return None
    try:
        return json.loads(m.group(0))
    except json.JSONDecodeError:
        return None

def _gateway_completion(
    system: str,
    user: str,
    *,
    max_tokens: int = 400,
    timeout: int | None = None,
) -> tuple[dict | None, int, str]:
    if not gateway_configured():
        return None, 0, ""
    ep = _ep()
    effective_timeout = timeout if timeout is not None else min(ep.gateway_timeout, _INLINE_GATEWAY_TIMEOUT)
    payload = {
        "model": ep.gateway_model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": 0.15,
        "max_tokens": max_tokens,
    }
    try:
        with _http_client(timeout=effective_timeout) as client:
            started = time.perf_counter()
            res = client.post(f"{_base_url()}/v1/chat/completions", json=payload)
            elapsed = int((time.perf_counter() - started) * 1000)
            if res.status_code != 200:
                return None, elapsed, ep.gateway_model
            body = res.json()
    except httpx.HTTPError:
        return None, 0, ep.gateway_model

    choices = body.get("choices") or []
    if not choices:
        return None, 0, ep.gateway_model
    content = (choices[0].get("message") or {}).get("content") or ""
    return _extract_json_block(content), elapsed, ep.gateway_model

def enrich_with_gateway(
    text: str,
    metadata: dict,
    local: dict,
    *,
    min_risk: float | None = None,
    force: bool = False,
) -> GatewayEnrichment | None:
    if not gateway_configured():
        return None
    if not force and not gateway_online_cached():
        return None
    ep = _ep()
    threshold = min_risk if min_risk is not None else ep.gateway_min_risk
    risk = float(local.get("risk_score") or 0)
    if not force and risk < threshold:
        return None

    username = metadata.get("user_name") or metadata.get("username") or "unknown"
    traits = metadata.get("style_traits") or {}
    layer_scores = (local.get("feature_vector") or {}).get("layer_scores") or {}

    system = (
        "Ты модуль безопасности корпоративного мессенджера. "
        "Ответь ТОЛЬКО JSON без markdown: "
        '{"title_ru":"...","explanation_ru":"...","alert_type":"style_anomaly|bec_intent|metadata_anomaly|synthetic_text|synthetic_voice",'
        '"intent_tags":["..."],'
        '"impersonation":false,"financial_pressure":false,"confidence":0.0}'
    )
    user = (
        f"Пользователь: {username}\n"
        f"Черты: {traits}\n"
        f"Скоры: {layer_scores}\n"
        f"risk: {risk}\n"
        f"Сообщение:\n{text[:2000]}"
    )

    parsed, elapsed, model = _gateway_completion(system, user)
    if not parsed:
        return GatewayEnrichment(
            explanation_ru=local.get("explanation_ru", ""),
            title_ru=local.get("title_ru", "Подозрительное сообщение"),
            alert_type=local.get("alert_type"),
            layer_hits=local.get("layer_hits"),
            inference_ms=elapsed,
            model=model,
        )

    lh = dict(local.get("layer_hits") or {})
    if parsed.get("intent_tags"):
        lh["l5_intent"] = 1
    if parsed.get("impersonation"):
        lh["l3_metadata"] = 1

    verdict = {
        "impersonation": bool(parsed.get("impersonation")),
        "financial_pressure": bool(parsed.get("financial_pressure")),
        "confidence": float(parsed.get("confidence") or 0),
        "intent_tags": parsed.get("intent_tags") or [],
    }

    return GatewayEnrichment(
        explanation_ru=str(parsed.get("explanation_ru") or local.get("explanation_ru", "")),
        title_ru=str(parsed.get("title_ru") or local.get("title_ru", "Подозрительное сообщение")),
        alert_type=str(parsed.get("alert_type") or local.get("alert_type") or "style_anomaly"),
        layer_hits=lh,
        inference_ms=elapsed,
        model=model,
        verdict=verdict,
    )

def gray_zone_judge(
    text: str,
    metadata: dict,
    local: dict,
) -> GatewayEnrichment | None:
    risk = float(local.get("risk_score") or 0)
    if risk < 0.35 or risk >= 0.55:
        return None
    if not gateway_configured():
        return None
    if not gateway_online_cached():
        return None

    system = (
        "Оцени сообщение для SOC. Только JSON: "
        '{"escalate":true|false,"confidence":0.0,"reason_ru":"...","alert_type":"style_anomaly|bec_intent|metadata_anomaly|synthetic_text"}'
    )
    user = f"risk={risk}\nmeta={metadata}\n{text[:1500]}"
    parsed, elapsed, model = _gateway_completion(system, user, max_tokens=280)
    if not parsed or not parsed.get("escalate"):
        return None

    return GatewayEnrichment(
        explanation_ru=str(parsed.get("reason_ru") or ""),
        title_ru="Серая зона: требуется проверка",
        alert_type=str(parsed.get("alert_type") or local.get("alert_type")),
        layer_hits=local.get("layer_hits"),
        inference_ms=elapsed,
        model=model,
        verdict={"gray_zone": True, "confidence": float(parsed.get("confidence") or 0)},
    )
