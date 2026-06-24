from datetime import UTC, datetime

SUSPICIOUS_CHANNELS = {"email", "telegram"}

def analyze_l3(text: str, metadata: dict) -> tuple[float, int, dict]:
    score = 0.0
    reasons: list[str] = []

    channel = (metadata.get("channel") or metadata.get("channel_name") or "").lower()
    if any(c in channel for c in SUSPICIOUS_CHANNELS):
        score += 0.35
        reasons.append("нестандартный канал")

    if metadata.get("impersonates_username") or metadata.get("impersonates"):
        score += 0.45
        reasons.append("подмена личности")

    user = (metadata.get("user_name") or metadata.get("username") or "").lower()
    role = (metadata.get("user_role") or "").lower()
    if user.startswith("scammer") or role == "scammer":
        if channel and "mattermost" not in channel:
            score += 0.25
            reasons.append("scammer вне mattermost")

    hour = datetime.now(UTC).hour
    traits = metadata.get("style_traits") or {}
    typical = traits.get("typical_hours") if isinstance(traits, dict) else None
    if typical and hour not in typical:
        score += 0.2
        reasons.append("вне типичных часов активности")
    elif hour < 6 or hour > 22:
        score += 0.12
        reasons.append("нерабочее время")

    if metadata.get("first_message_in_channel"):
        score += 0.18
        reasons.append("первое сообщение в канале")

    if metadata.get("channel_switch_24h"):
        score += 0.22
        reasons.append("смена канала за 24ч")

    score = min(score, 1.0)
    hit = 1 if score >= 0.28 else 0
    return score, hit, {"reasons": reasons, "metadata_anomaly_score": score}
