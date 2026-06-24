from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

import httpx

from app.services.secure_bundle import get_inference_endpoints

@dataclass(frozen=True)
class VoiceAnalysis:
    spoof_score: float
    speaker_match: float
    voice_risk: float
    l6_hit: int
    detail: str

def voice_analyze_configured() -> bool:
    return bool(get_inference_endpoints().voice_base)

def analyze_voice_file(path: Path, *, username: str, enrolled: list[float] | None) -> VoiceAnalysis | None:
    ep = get_inference_endpoints()
    if not ep.voice_base:
        return None

    url = f"{ep.voice_base.rstrip('/')}/analyze"
    headers: dict[str, str] = {}
    if ep.voice_token:
        headers["Authorization"] = f"Bearer {ep.voice_token}"

    form: dict[str, str] = {"username": username}
    if enrolled:
        form["enrolled_embedding"] = json.dumps(enrolled)

    try:
        with httpx.Client(timeout=ep.voice_timeout) as client:
            with path.open("rb") as fh:
                res = client.post(
                    url,
                    headers=headers,
                    files={"file": (path.name, fh, "application/octet-stream")},
                    data=form,
                )
            if res.status_code != 200:
                return None
            data = res.json()
    except httpx.HTTPError:
        return None

    spoof = float(data.get("spoof_score") or 0)
    speaker = float(data.get("speaker_match") or 1.0)
    risk = float(data.get("voice_risk") or 0)
    hit = 1 if data.get("l6_hit") else (1 if risk >= 0.42 else 0)
    return VoiceAnalysis(
        spoof_score=spoof,
        speaker_match=speaker,
        voice_risk=risk,
        l6_hit=hit,
        detail=str(data.get("detail") or ""),
    )

def enroll_voice_remote(path: Path, username: str) -> list[float] | None:
    ep = get_inference_endpoints()
    if not ep.voice_base:
        return None
    url = f"{ep.voice_base.rstrip('/')}/enroll"
    headers: dict[str, str] = {}
    if ep.voice_token:
        headers["Authorization"] = f"Bearer {ep.voice_token}"
    try:
        with httpx.Client(timeout=ep.voice_timeout) as client:
            with path.open("rb") as fh:
                res = client.post(
                    url,
                    headers=headers,
                    files={"file": (path.name, fh, "application/octet-stream")},
                    data={"username": username},
                )
            if res.status_code != 200:
                return None
            data = res.json()
            emb = data.get("embedding")
            if isinstance(emb, list) and emb:
                return [float(x) for x in emb]
    except httpx.HTTPError:
        return None
    return None
