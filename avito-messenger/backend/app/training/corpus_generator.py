from __future__ import annotations

import random
import re
from typing import Any

from app.training.corpus_v1_seeds import (
    CORPUS_VERSION,
    _s,
    all_samples as manual_samples,
)

TARGET_TOTAL = 1000
GEN_SEED = 42

RU_TF_LEGIT = [
    "Добрый день. Направляю {doc} для согласования до {time}.",
    "Коллеги, напоминаю о дедлайне по {project} — {date}.",
    "Прошу подтвердить получение {doc}.",
    "Уведомляю о переносе встречи на {time} {date}.",
    "Отчёт по {project} готов, ссылка в Confluence.",
    "Согласовано с {dept}, можно запускать следующий этап.",
    "Ваш тикет #{num} принят, ожидайте ответ в течение {hours} ч.",
    "Благодарю за обратную связь по {topic}.",
    "План работ на неделю отправлен на почту.",
    "Результаты ревью кода по PR-{num} — без блокеров.",
]

RU_TI_LEGIT = [
    "ок гляну",
    "скинь {doc}",
    "завтра сделаю",
    "я на созвоне",
    "мерджим?",
    "спс",
    "привет, видел {topic}?",
    "ща проверю",
    "норм идея",
    "го в {time}",
    "перезвоню",
    "не успеваю сегодня",
    "залил фикс",
    "апрувнул",
    "глянь плз тред",
]

EN_TF_LEGIT = [
    "Please find attached the {doc} for review by {date}.",
    "Reminder: {project} deadline is {date}.",
    "Your ticket #{num} is in progress, ETA {hours}h.",
    "Meeting moved to {time} on {date}.",
    "Code review for PR-{num} completed, no blockers.",
    "Thanks for the update on {topic}.",
    "The deployment to staging is scheduled for {date}.",
    "Confirmed receipt of the signed {doc}.",
]

EN_TI_LEGIT = [
    "ok will check",
    "send me the {doc}",
    "tomorrow works",
    "on a call brb",
    "lgtm",
    "thanks!",
    "hey saw {topic}?",
    "fix is up",
    "approved",
    "sync at {time}?",
]

RU_TF_BEC = [
    "Уважаемый коллега, срочно переведите {amount} руб. на счёт {vendor}. Конфиденциально.",
    "Я на совещании. Переведите средства до {time}, иначе сорвётся сделка.",
    "Прошу оплатить счёт поставщика по новым реквизитам во вложении.",
    "Конфиденциально: wire transfer {amount} USD, не обсуждайте с финслужбой.",
    "Срочно одобрите платёж {amount} руб. от моего имени.",
]

RU_TI_BEC = [
    "слушай срочно кинь {amount} на карту",
    "я с нового номера это {name} переведи asap",
    "кинь на карту до {time} потом объясню",
    "срочно нужен перевод {amount} никому не говори",
]

RU_TF_PHISH = [
    "Пройдите 2FA по ссылке в течение часа: {url}",
    "Ваш доступ заблокирован. Подтвердите учётную запись: {url}",
    "Обновите пароль корпоративной почты: {url}",
    "Служба ИБ: пройдите проверку по {url}",
]

RU_TI_PHISH = [
    "скинь пароль от vpn срочно",
    "залогинься тут {url} бонус ждёт",
    "дай код из смс для банка",
    "перейди по ссылке подтверди аккаунт {url}",
]

EN_TF_BEC = [
    "Kindly wire ${amount} to the account below today. I am in meetings.",
    "Confidential: approve emergency payment of ${amount} before {time}.",
    "Please pay the vendor using the new bank details attached.",
]

EN_TI_BEC = [
    "hey wire ${amount} today its {name} new phone",
    "send login asap locked out",
    "dont tell finance crypto wallet below",
]

EN_TF_PHISH = [
    "Reset your password immediately: {url}",
    "Verify your MFA at {url} within 30 minutes.",
    "IT Security: confirm your account at {url}",
]

RU_VOICE_FILL = ["ну ", "эм ", "короче ", "слушай ", "алло "]
EN_VOICE_FILL = ["um ", "so ", "hey ", "like "]

SLOTS = {
    "amount": lambda: random.choice(["50 000", "120 000", "480 000", "15 000", "850 000", "25 000"]),
    "amount_usd": lambda: random.choice(["5000", "85000", "125000", "25000"]),
    "vendor": lambda: random.choice(["ООО Альфа", "TechSupply Ltd", "контрагент", "новый поставщик"]),
    "doc": lambda: random.choice(["договор", "акт", "отчёт", "contract", "invoice", "report"]),
    "project": lambda: random.choice(["релиз", "миграция", "аудит", "release", "migration"]),
    "time": lambda: random.choice(["15:00", "17:00", "10:30", "18:00", "3pm", "5pm"]),
    "date": lambda: random.choice(["15.06", "20.05", "завтра", "Friday", "Monday"]),
    "hours": lambda: str(random.choice([2, 4, 8, 24])),
    "num": lambda: str(random.randint(100, 9999)),
    "dept": lambda: random.choice(["ИБ", "финансы", "legal", "HR"]),
    "topic": lambda: random.choice(["релиз", "бюджет", "sprint", "deploy"]),
    "name": lambda: random.choice(["Алексей", "CEO", "Alex", "директор"]),
    "url": lambda: random.choice([
        "secure-mail-verify.ru/login",
        "avito-staff-auth.com",
        "corp-login-check.net",
        "http://payroll-bonus.ru",
    ]),
}

EXPLAIN = {
    "bec_intent": (
        "Подозрительный финансовый запрос",
        "Срочность, перевод денег и/или секретность не характерны для профиля отправителя.",
    ),
    "metadata_anomaly": (
        "Фишинг учётных данных",
        "Запрос пароля, 2FA или входа по сторонней ссылке.",
    ),
    "style_anomaly": (
        "Аномалия стиля",
        "Регистр, длина или вежливость не совпадают с типичным поведением пользователя.",
    ),
    "phishing": (
        "Фишинг",
        "Подозрительная ссылка или запрос учётных данных.",
    ),
    "suspicious": (
        "Подозрительное сообщение",
        "Комбинация признаков социальной инженерии.",
    ),
    "ai_generated": (
        "Признаки AI-текста",
        "Чрезмерно шаблонная вежливость и структура, нетипичные для профиля.",
    ),
}

def _fill(template: str, lang: str) -> str:
    text = template
    for key, fn in SLOTS.items():
        if "{" + key + "}" in text:
            text = text.replace("{" + key + "}", fn())
    if lang == "en" and "{amount}" in template:
        text = text.replace("${amount}", random.choice(["5000", "85000", "25000"]))
    return text

def _voice_wrap(text: str, lang: str, register: str) -> str:
    if register == "informal":
        pref = random.choice(RU_VOICE_FILL if lang == "ru" else EN_VOICE_FILL)
        return pref + text[0].lower() + text[1:] if text else text
    return text

def _pick_attack_templates(lang: str, register: str) -> tuple[str, str, str]:
    label_roll = random.random()
    if label_roll < 0.35:
        label, alert = "impersonation", "bec_intent"
        pool = (RU_TF_BEC if register == "formal" else RU_TI_BEC) if lang == "ru" else (
            EN_TF_BEC if register == "formal" else EN_TI_BEC
        )
    elif label_roll < 0.7:
        label, alert = "phishing", "metadata_anomaly"
        pool = (RU_TF_PHISH if register == "formal" else RU_TI_PHISH) if lang == "ru" else (
            EN_TF_PHISH if register == "formal" else EN_TF_PHISH
        )
    elif label_roll < 0.9:
        label, alert = "suspicious", "bec_intent"
        pool = (RU_TI_BEC + RU_TF_BEC) if lang == "ru" else (EN_TI_BEC + EN_TF_BEC)
    else:
        label, alert = "ai_generated", "style_anomaly"
        pool = RU_TF_BEC if lang == "ru" else EN_TF_BEC
    return label, alert, random.choice(pool)

def _generate_one(idx: int, rng: random.Random) -> dict[str, Any]:
    lang = rng.choice(["ru", "en"])
    register = rng.choice(["formal", "informal"])
    modality = "voice" if rng.random() < 0.15 else "text"
    is_attack = rng.random() < 0.42
    split = "val" if idx % 20 == 0 else "train"
    style_traits: dict | None = None

    if is_attack:
        label, alert_type, tmpl = _pick_attack_templates(lang, register)
        text = _fill(tmpl, lang)
        persona = "scammer"
        impersonates = "ceo" if label == "impersonation" and rng.random() < 0.7 else None
        title, expl = EXPLAIN.get(alert_type, EXPLAIN["suspicious"])
        if label == "phishing":
            title, expl = EXPLAIN["phishing"]
    else:
        label = "legit"
        alert_type = None
        persona = rng.choice(["employee", "ceo", "dev", "hr", "pm", "support"])
        impersonates = None
        title = expl = None
        pool = {
            ("ru", "formal"): RU_TF_LEGIT,
            ("ru", "informal"): RU_TI_LEGIT,
            ("en", "formal"): EN_TF_LEGIT,
            ("en", "informal"): EN_TI_LEGIT,
        }[(lang, register)]
        text = _fill(rng.choice(pool), lang)
        if persona == "ceo" and register == "informal":
            style_traits = {"short_messages": True}

    if modality == "voice":
        text = _voice_wrap(text, lang, register)

    sid = f"gen_{lang}_{register[0]}{modality[0]}_{idx:04d}"
    return _s(
        sid,
        text,
        language=lang,
        register=register,
        modality=modality,
        label=label,
        persona=persona,
        impersonates=impersonates,
        alert_type=alert_type,
        title_ru=title,
        explanation_ru=expl,
        split=split,
        style_traits=style_traits,
    )

def _norm_key(text: str) -> str:
    return re.sub(r"\s+", " ", text.lower().strip())[:120]

def generate_corpus(target: int = TARGET_TOTAL) -> list[dict[str, Any]]:
    manual = manual_samples()
    seen_text: set[str] = {_norm_key(s["text"]) for s in manual}
    out = list(manual)
    rng = random.Random(GEN_SEED)
    idx = 0
    attempts = 0
    max_attempts = target * 5
    while len(out) < target and attempts < max_attempts:
        attempts += 1
        rec = _generate_one(idx, rng)
        idx += 1
        key = _norm_key(rec["text"])
        if key in seen_text:
            continue
        seen_text.add(key)
        rec["source"] = "generated_v1"
        out.append(rec)
    return out[:target]

def all_samples_expanded() -> list[dict[str, Any]]:
    return generate_corpus(TARGET_TOTAL)
