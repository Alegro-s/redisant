from __future__ import annotations

import re

ENTITY_PATTERNS = (
    (r"https?://[^\s<>\"{}|\\^`\[\]]+", "external_url", 0.42),
    (r"\b(?:высла|отправ|пришл|скинь).{0,30}(?:данн|информац|файл)\b", "data_exfil_request", 0.38),
    (r"\b\d{1,3}(?:\s?\d{3})+(?:[.,]\d{2})?\s*(?:руб|₽|rub)\b", "money_amount", 0.32),
    (r"\b(?:iban|бик|р/с|рс|счёт|счет|реквизит|карта)\b", "payment_instrument", 0.35),
    (r"\b(?:срочно|немедленно|asap|до конца дня|в течение часа)\b", "urgency", 0.28),
    (r"\b(?:парол|2fa|otp|код доступа|vpn|учётк|учетк)\b", "credentials", 0.38),
    (r"\b(?:конфиденциальн|не говори|между нами|только ты)\b", "secrecy", 0.3),
    (r"\b(?:btc|usdt|bitcoin|крипт|трейдинг|трейд)\b", "crypto", 0.34),
    (r"\b(?:депозит|влож\w+|инвести\w+)\b", "deposit_request", 0.38),
    (r"\b(?:заработ\w+|доход|прибыл\w+)\b", "profit_promise", 0.34),
    (r"\b\d{1,3}\s*%", "percent_yield", 0.32),
    (r"\b(?:аналитическ\w+ отдел|провед\w+ сделк)\b", "invest_pitch", 0.32),
    (r"\b(?:ceo|директор|руководств|генеральн)\b", "executive_ref", 0.22),
)

def extract_intent_entities(text: str, metadata: dict) -> tuple[float, int, dict]:
    low = text.lower()
    score = 0.0
    tags: list[str] = []
    for pattern, tag, weight in ENTITY_PATTERNS:
        if re.search(pattern, low, re.IGNORECASE):
            score += weight
            tags.append(tag)
    if metadata.get("impersonates_username") or metadata.get("impersonates"):
        score += 0.3
        tags.append("impersonation_meta")
    target = (metadata.get("impersonates_username") or "").lower()
    sender = (metadata.get("user_name") or metadata.get("username") or "").lower()
    if target and target != sender:
        score += 0.15
        tags.append("identity_mismatch")
    score = min(score, 1.0)
    hit = 1 if score >= 0.3 else 0
    return score, hit, {"intent_entity_score": score, "intent_entities": tags}
