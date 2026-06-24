from __future__ import annotations

def analyze_l6(voice_extras: dict | None) -> tuple[float, int, dict]:
    if not voice_extras:
        return 0.0, 0, {}
    spoof = float(voice_extras.get("spoof_score") or 0)
    speaker = float(voice_extras.get("speaker_match") or 1.0)
    voice_risk = float(voice_extras.get("voice_risk") or 0)
    if voice_risk <= 0:
        voice_risk = min(1.0, spoof * 0.55 + (1.0 - speaker) * 0.45)
    hit = 1 if voice_extras.get("l6_hit") else (1 if voice_risk >= 0.42 else 0)
    return voice_risk, hit, {
        "spoof_score": spoof,
        "speaker_match": speaker,
        "voice_risk": voice_risk,
        "detail": voice_extras.get("detail") or "",
    }
