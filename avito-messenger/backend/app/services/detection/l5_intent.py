import re

INTENT_PATTERNS = [
    (r"https?://|www\.\S+", 0.4, "внешняя ссылка"),
    (r"высла\w*|отправ\w*|пришл\w*.{0,20}данн", 0.36, "запрос данных"),
    (r"перейд\w*.{0,25}ссылк", 0.34, "переход по ссылке"),
    (r"перевод|перевести|средств|счёт|счет|реквизит|оплат|депозит|влож", 0.38, "финансы"),
    (r"срочно|немедленно|в течение часа|до конца дня|сейчас", 0.28, "срочность"),
    (r"парол|код|2fa|доступ|vpn|учётк|учетк", 0.38, "учётные данные"),
    (r"конфиденциальн|не говори|никому не сообщай|между нами", 0.32, "секретность"),
    (r"bitcoin|btc|крипт|usdt|трейдинг|трейд", 0.35, "крипто"),
    (r"заработ\w+|доход|прибыл\w+|\d{1,3}\s*%", 0.34, "обещание дохода"),
    (r"аналитическ\w+ отдел|провед\w+ сделк", 0.32, "инвест-схема"),
    (r"ceo|директор|руководств|алексей", 0.22, "импersonация"),
]

def analyze_l5(text: str, metadata: dict) -> tuple[float, int, dict]:
    low = text.lower()
    score = 0.0
    tags: list[str] = []
    for pattern, weight, tag in INTENT_PATTERNS:
        if re.search(pattern, low):
            score += weight
            tags.append(tag)
    if metadata.get("impersonates_username"):
        score += 0.28
        tags.append("meta_impersonation")

    score = min(score, 1.0)
    hit = 1 if score >= 0.28 else 0
    return score, hit, {"intent_score": score, "intent_tags": tags}
