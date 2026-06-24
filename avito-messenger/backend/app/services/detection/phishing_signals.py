from __future__ import annotations

import re

_URL_RE = re.compile(r"https?://[^\s<>\"{}|\\^`\[\]]+", re.IGNORECASE)
_SHORT_URL_RE = re.compile(r"\b(?:t\.me|bit\.ly|goo\.gl|tinyurl\.com|clck\.ru)/\S+", re.IGNORECASE)

_DATA_REQUEST_PATTERNS = (
    (r"\b(?:высла|отправ|пришл|передай|скинь|дай|поделись).{0,35}(?:данн|информац|файл|доступ|реквизит)", 0.38),
    (r"\b(?:данн|парол|код|cvv|pin|логин|реквизит).{0,25}(?:высла|отправ|пришл|скинь|дай)", 0.4),
    (r"\b(?:перейд|переход|открой|кликн|зайд).{0,30}(?:ссылк|сайт|url|линк)", 0.34),
    (r"\b(?:узнаете|узнаешь).{0,25}(?:перейд|ссылк|ссылке)", 0.36),
)

_INVESTMENT_SCAM_PATTERNS = (
    (r"\b(?:депозит|внес\w*|инвести\w+|влож\w+).{0,45}(?:заработ|доход|прибыл|\d{1,3}\s*%)", 0.46),
    (r"\b(?:заработ\w+|доход|прибыл\w+).{0,40}(?:\d{1,3}\s*%|процент)", 0.44),
    (r"\b(?:трейдинг|трейд|форекс|forex).{0,55}(?:bitcoin|btc|крипт|usdt|сделк)", 0.44),
    (r"\b(?:bitcoin|btc|крипт|usdt).{0,50}(?:заработ|депозит|сделк|провед\w+)", 0.44),
    (r"\b(?:аналитическ\w+ отдел|сигнал\w+|аномали\w+).{0,40}(?:график|bitcoin|btc|крипт)", 0.42),
    (r"\b(?:минимальн\w+ вход|гарантированн\w+ доход|без риска|быстрый доход)", 0.4),
    (r"\b(?:за \d+ час\w+).{0,35}(?:заработ|получ|прибыл)", 0.42),
)

_SUSPICIOUS_DOMAIN_HINTS = (
    "finteka",
    "verify-",
    "secure-login",
    "account-update",
    "wallet-",
    "crypto-",
)

def evaluate_phishing_signals(text: str, metadata: dict | None = None) -> dict:
    """Явные признаки фишинга: ссылки, запрос данных, роль scammer."""
    metadata = metadata or {}
    low = text.lower()
    score = 0.0
    signals: list[str] = []

    has_url = bool(_URL_RE.search(text) or _SHORT_URL_RE.search(text))
    if has_url:
        score += 0.44
        signals.append("external_link")
        for hint in _SUSPICIOUS_DOMAIN_HINTS:
            if hint in low:
                score += 0.18
                signals.append("suspicious_domain")
                break

    data_request = False
    for pattern, weight in _DATA_REQUEST_PATTERNS:
        if re.search(pattern, low, re.IGNORECASE):
            score += weight
            data_request = True
            signals.append("data_request")
            break

    investment_scam = False
    for pattern, weight in _INVESTMENT_SCAM_PATTERNS:
        if re.search(pattern, low, re.IGNORECASE):
            score += weight
            investment_scam = True
            signals.append("investment_scam")
            break

    role = (metadata.get("user_role") or "").lower()
    if role == "scammer":
        score += 0.32
        signals.append("known_scammer_role")

    if has_url and data_request:
        score += 0.22
        signals.append("phishing_combo")

    if has_url and role == "scammer":
        score += 0.15
        signals.append("scammer_link")

    score = min(score, 1.0)
    force_alert = (
        score >= 0.58
        or (role == "scammer" and has_url and data_request)
        or investment_scam
    )

    alert_type = "bec_intent"
    if investment_scam:
        alert_type = "investment_scam"
    elif has_url:
        alert_type = "metadata_anomaly"

    parts: list[str] = []
    if "external_link" in signals:
        parts.append("внешняя ссылка")
    if "data_request" in signals:
        parts.append("запрос данных")
    if "known_scammer_role" in signals:
        parts.append("отправитель с ролью scammer")
    if "suspicious_domain" in signals:
        parts.append("подозрительный домен")
    if "phishing_combo" in signals:
        parts.append("связка «ссылка + данные»")
    if "investment_scam" in signals:
        parts.append("инвестиционное мошенничество")

    explanation = (
        "Признаки мошенничества: " + ", ".join(parts) + f". Риск {int(score * 100)}%."
        if parts
        else ""
    )
    title = "Возможное мошенничество" if score >= 0.45 else "Подозрительное сообщение"

    return {
        "phishing_score": round(score, 4),
        "phishing_signals": signals,
        "force_alert": force_alert,
        "alert_type": alert_type,
        "title_ru": title,
        "explanation_ru": explanation,
        "layer_hit": 1 if score >= 0.28 else 0,
    }
