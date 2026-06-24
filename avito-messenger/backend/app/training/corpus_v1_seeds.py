from __future__ import annotations

from typing import Any

CORPUS_VERSION = "neural_trust_corpus_v2"

def _s(
    sid: str,
    text: str,
    *,
    language: str,
    register: str,
    modality: str = "text",
    label: str = "legit",
    persona: str = "employee",
    impersonates: str | None = None,
    channel: str = "dm",
    alert_type: str | None = None,
    title_ru: str | None = None,
    explanation_ru: str | None = None,
    split: str = "train",
    duration_sec: int | None = None,
    style_traits: dict | None = None,
) -> dict[str, Any]:
    rec: dict[str, Any] = {
        "id": sid,
        "corpus_version": CORPUS_VERSION,
        "text": text,
        "modality": modality,
        "language": language,
        "register": register,
        "label": label,
        "persona": persona,
        "impersonates": impersonates,
        "channel": channel,
        "alert_type": alert_type,
        "style_traits": style_traits or {},
        "split": split,
        "source": "seed_v1",
        "is_gold": True,
    }
    if title_ru:
        rec["gold_title_ru"] = title_ru
    if explanation_ru:
        rec["gold_explanation_ru"] = explanation_ru
    if modality == "voice":
        rec["voice"] = {
            "transcript": text,
            "audio_path": f"corpus/audio/{language}/{register}/{sid}.webm",
            "duration_sec": duration_sec or max(4, len(text.split()) // 2),
            "asr_source": "manual_transcript",
            "note": "Запишите ГС по транскрипту или синтезируйте TTS для Whisper-fine-tune",
        }
    return rec

RU_FORMAL_LEGIT = [
    _s("ru_tf_l001", "Уважаемые коллеги, направляю протокол совещания от 15.05. Прошу ознакомиться до конца дня.", language="ru", register="formal", persona="hr", channel="group"),
    _s("ru_tf_l002", "Добрый день. Подтверждаю получение договора. Замечания направлю отдельным письмом.", language="ru", register="formal", persona="legal", channel="email"),
    _s("ru_tf_l003", "Коллеги, напоминаю о необходимости сдачи отчётности по ИБ до 18:00.", language="ru", register="formal", persona="security", channel="group"),
    _s("ru_tf_l004", "Здравствуйте. Ваш запрос на доступ к CRM принят в работу, SLA — 2 рабочих дня.", language="ru", register="formal", persona="support"),
    _s("ru_tf_l005", "Прошу согласовать перенос релиза на 14.06 с учётом результатов нагрузочного тестирования.", language="ru", register="formal", persona="pm", channel="group"),
    _s("ru_tf_l006", "Уведомляем о плановых работах в дата-центре 22.05 с 02:00 до 04:00 МСК.", language="ru", register="formal", persona="infra", channel="group"),
    _s("ru_tf_l007", "Алексей, добрый день. Отправил согласованную версию презентации для совета директоров.", language="ru", register="formal", persona="assistant", impersonates=None),
    _s("ru_tf_l008", "Направляю акт выполненных работ и счёт-фактуру. Просьба подтвердить получение.", language="ru", register="formal", persona="finance", channel="email"),
    _s("ru_tf_l009", "Коллеги, обновлён регламент удалённого доступа. Документ в Confluence, раздел IT.", language="ru", register="formal", persona="it", channel="group"),
    _s("ru_tf_l010", "Благодарю за оперативный ответ. Вопрос по миграции БД закрыт.", language="ru", register="formal", persona="dba"),
]

RU_INFORMAL_LEGIT = [
    _s("ru_ti_l001", "ок, гляну вечером", language="ru", register="informal", persona="ceo", style_traits={"short_messages": True, "signature": "АС"}),
    _s("ru_ti_l002", "скинь ссылку на созвон", language="ru", register="informal", persona="dev"),
    _s("ru_ti_l003", "я на обеде, отвечу через час", language="ru", register="informal", persona="employee"),
    _s("ru_ti_l004", "норм, мержим", language="ru", register="informal", persona="dev", channel="group"),
    _s("ru_ti_l005", "привет, ты видел тикет 8842?", language="ru", register="informal", persona="qa"),
    _s("ru_ti_l006", "завтра не смогу, перенесём?", language="ru", register="informal", persona="manager"),
    _s("ru_ti_l007", "ага, принял", language="ru", register="informal", persona="ceo", style_traits={"short_messages": True}),
    _s("ru_ti_l008", "щас посмотрю логи", language="ru", register="informal", persona="sre"),
    _s("ru_ti_l009", "спс, выручил", language="ru", register="informal", persona="employee"),
    _s("ru_ti_l010", "го в 15:00 в зум", language="ru", register="informal", persona="pm", channel="group"),
]

EN_FORMAL_LEGIT = [
    _s("en_tf_l001", "Dear team, please find attached the Q2 compliance report for your review.", language="en", register="formal", persona="compliance", channel="email"),
    _s("en_tf_l002", "Good morning. Your access request has been approved. Credentials will arrive in a separate email.", language="en", register="formal", persona="it"),
    _s("en_tf_l003", "Please confirm receipt of the signed NDA by end of business today.", language="en", register="formal", persona="legal"),
    _s("en_tf_l004", "We scheduled maintenance for Sunday 02:00–04:00 UTC. No action required.", language="en", register="formal", persona="infra", channel="group"),
    _s("en_tf_l005", "Thank you for the update. The invoice has been processed.", language="en", register="formal", persona="finance"),
    _s("en_tf_l006", "Kindly review the draft policy and share feedback by Friday.", language="en", register="formal", persona="hr", channel="group"),
    _s("en_tf_l007", "The deployment to staging completed successfully. QA may begin.", language="en", register="formal", persona="devops"),
    _s("en_tf_l008", "Please join the board prep call at 10:00 ET. Dial-in in the calendar invite.", language="en", register="formal", persona="assistant"),
]

EN_INFORMAL_LEGIT = [
    _s("en_ti_l001", "yep, on it", language="en", register="informal", persona="ceo", style_traits={"short_messages": True}),
    _s("en_ti_l002", "can u send the link?", language="en", register="informal", persona="dev"),
    _s("en_ti_l003", "brb lunch", language="en", register="informal", persona="employee"),
    _s("en_ti_l004", "looks good, ship it", language="en", register="informal", persona="lead", channel="group"),
    _s("en_ti_l005", "hey did u see the alert?", language="en", register="informal", persona="sre"),
    _s("en_ti_l006", "tomorrow works for me", language="en", register="informal", persona="pm"),
    _s("en_ti_l007", "thanks!", language="en", register="informal", persona="employee"),
    _s("en_ti_l008", "lets sync at 3", language="en", register="informal", persona="manager", channel="group"),
]

RU_FORMAL_ATTACK = [
    _s(
        "ru_tf_a001",
        "Уважаемый коллега, будьте добры срочно перевести 480 000 руб. на счёт контрагента. Реквизиты ниже. Конфиденциально.",
        language="ru", register="formal", label="impersonation", persona="scammer", impersonates="ceo",
        alert_type="bec_intent", split="train",
        title_ru="Подозрительный запрос на перевод",
        explanation_ru="Не характерна вежливая формальная форма и срочный финансовый запрос для профиля CEO, который обычно пишет кратко.",
    ),
    _s(
        "ru_tf_a002",
        "Добрый день. Я на совещании, не могу говорить. Переведите средства на резервный счёт до 17:00, иначе сорвётся сделка.",
        language="ru", register="formal", label="impersonation", persona="scammer", impersonates="ceo",
        alert_type="bec_intent",
        title_ru="Имитация руководителя",
        explanation_ru="Сочетание срочности, секретности и перевода денег — типичный BEC; стиль не совпадает с короткими сообщениями CEO.",
    ),
    _s(
        "ru_tf_a003",
        "Прошу немедленно обновить пароль корпоративной почты по ссылке: http://secure-mail-verify.ru/login",
        language="ru", register="formal", label="phishing", persona="scammer", alert_type="metadata_anomaly",
        title_ru="Фишинг учётных данных",
        explanation_ru="Запрос пароля по внешней ссылке; домен не корпоративный.",
    ),
    _s(
        "ru_tf_a004",
        "Уважаемые сотрудники, в связи с проверкой СБ пройдите 2FA по ссылке в течение часа.",
        language="ru", register="formal", label="phishing", persona="scammer", channel="group",
        title_ru="Подозрительная 2FA",
        explanation_ru="Срочность + учётные данные + массовая рассылка без официального канала ИБ.",
    ),
    _s(
        "ru_tf_a005",
        "Коллега, конфиденциально: перевод на USDT кошелёк для закрытия NDA. Не обсуждайте с финслужбой.",
        language="ru", register="formal", label="suspicious", persona="scammer", alert_type="bec_intent",
        title_ru="Крипто и секретность",
        explanation_ru="Криптовалюта, секретность, обход финслужбы — высокий intent-score L5.",
    ),
    _s(
        "ru_tf_a006",
        "Здравствуйте. Ваш корпоративный доступ будет заблокирован. Подтвердите учётную запись: avito-staff-auth.com",
        language="ru", register="formal", label="phishing", persona="scammer",
        title_ru="Фишинг блокировки",
        explanation_ru="Давление через блокировку + сторонний домен.",
    ),
    _s(
        "ru_tf_a007",
        "Благодарю за сотрудничество. Прошу срочно оплатить счёт поставщика по реквизитам во вложении (новые реквизиты).",
        language="ru", register="formal", label="impersonation", persona="scammer", impersonates="finance",
        alert_type="bec_intent",
        title_ru="Подмена реквизитов",
        explanation_ru="Смена реквизитов + срочность — классическая схема BEC.",
    ),
    _s(
        "ru_tf_a008",
        "Уважаемый Алексей, как ваш CEO, прошу лично одобрить wire transfer на $125,000. Это срочно и между нами.",
        language="ru", register="formal", label="ai_generated", persona="scammer", impersonates="ceo",
        alert_type="style_anomaly",
        title_ru="Слишком «идеальный» английский в русском контексте",
        explanation_ru="Чрезмерная вежливость, смешение языков и шаблон BEC; не совпадает с профилем.",
    ),
]

RU_INFORMAL_ATTACK = [
    _s("ru_ti_a001", "слушай срочно кинь на карту 50к, потом объясню", language="ru", register="informal", label="suspicious", persona="scammer", impersonates="ceo", alert_type="bec_intent", title_ru="Срочный перевод", explanation_ru="Неформальный тон, но финансовый запрос от лица CEO нетипичен."),
    _s("ru_ti_a002", "я с нового номера, это CEO, переведи на этот счёт asap", language="ru", register="informal", label="impersonation", persona="scammer", impersonates="ceo", alert_type="bec_intent"),
    _s("ru_ti_a003", "скинь пароль от vpn, я devops, срочно", language="ru", register="informal", label="phishing", persona="scammer", alert_type="metadata_anomaly"),
    _s("ru_ti_a004", "тут ссылка на бонус 100к, залогинься быстрее", language="ru", register="informal", label="phishing", persona="scammer"),
    _s("ru_ti_a005", "не говори никому, кинь btc на кошелёк", language="ru", register="informal", label="suspicious", persona="scammer", alert_type="bec_intent"),
    _s("ru_ti_a006", "алексей тут? срочно нужен код из смс для банка", language="ru", register="informal", label="phishing", persona="scammer"),
]

EN_FORMAL_ATTACK = [
    _s(
        "en_tf_a001",
        "Dear colleague, kindly wire $85,000 to the vendor account below today. I am in meetings and cannot call.",
        language="en", register="formal", label="impersonation", persona="scammer", impersonates="ceo",
        alert_type="bec_intent",
        title_ru="BEC на английском",
        explanation_ru="Formal wire request + urgency + CEO impersonation.",
    ),
    _s(
        "en_tf_a002",
        "Please reset your password immediately using this link to avoid account suspension.",
        language="en", register="formal", label="phishing", persona="scammer",
        title_ru="Credential phishing",
        explanation_ru="Urgent password reset via external link.",
    ),
    _s(
        "en_tf_a003",
        "Confidential: approve the emergency payment to our new supplier account before 5 PM.",
        language="en", register="formal", label="impersonation", persona="scammer", alert_type="bec_intent",
    ),
    _s(
        "en_tf_a004",
        "Hello, this is IT Security. Verify your MFA token at the portal within 30 minutes.",
        language="en", register="formal", label="phishing", persona="scammer", channel="group",
    ),
    _s(
        "en_tf_a005",
        "Good day. Your executive assistant requested urgent Bitcoin transfer for a private acquisition.",
        language="en", register="formal", label="suspicious", persona="scammer", alert_type="bec_intent",
    ),
]

EN_INFORMAL_ATTACK = [
    _s("en_ti_a001", "hey send me the login asap im locked out", language="en", register="informal", label="phishing", persona="scammer"),
    _s("en_ti_a002", "its me ceo new phone wire 20k pls", language="en", register="informal", label="impersonation", persona="scammer", impersonates="ceo", alert_type="bec_intent"),
    _s("en_ti_a003", "check this payroll bonus link and sign in", language="en", register="informal", label="phishing", persona="scammer"),
    _s("en_ti_a004", "dont tell finance, crypto wallet below", language="en", register="informal", label="suspicious", persona="scammer", alert_type="bec_intent"),
]

RU_VOICE_LEGIT = [
    _s("ru_vf_l001", "ну я посмотрел, вроде норм, давай завтра созвонимся", language="ru", register="informal", modality="voice", persona="ceo", duration_sec=6),
    _s("ru_vf_l002", "эм, скинь мне файл ещё раз, не открывается", language="ru", register="informal", modality="voice", persona="employee", duration_sec=5),
    _s("ru_vf_l003", "я на линии, перезвоню через десять минут", language="ru", register="informal", modality="voice", persona="manager", duration_sec=4),
    _s("ru_vf_l004", "Добрый день, подтверждаю, документы получил, спасибо.", language="ru", register="formal", modality="voice", persona="legal", duration_sec=7),
    _s("ru_vf_l005", "ага, принял задачу, сделаю к вечеру", language="ru", register="informal", modality="voice", persona="dev", duration_sec=5),
    _s("ru_vf_l006", "слушай, а мы релиз не переносим?", language="ru", register="informal", modality="voice", persona="pm", channel="group", duration_sec=4),
]

RU_VOICE_ATTACK = [
    _s(
        "ru_vf_a001",
        "алло, это Алексей, я с нового телефона, срочно переведи на карту, потом объясню, никому не говори",
        language="ru", register="informal", modality="voice", label="impersonation", persona="scammer",
        impersonates="ceo", alert_type="bec_intent", duration_sec=9,
        title_ru="Голосовой BEC",
        explanation_ru="Срочный перевод + секретность в ГС; имитация CEO.",
    ),
    _s(
        "ru_vf_a002",
        "Уважаемый сотрудник, пройдите по ссылке для подтверждения доступа, иначе аккаунт заблокируют сегодня.",
        language="ru", register="formal", modality="voice", label="phishing", persona="scammer", duration_sec=8,
        title_ru="Фишинг в голосовом",
        explanation_ru="Угроза блокировки и запрос пройти по ссылке.",
    ),
    _s(
        "ru_vf_a003",
        "ну короче кинь пароль от vpn, я из it, очень срочно",
        language="ru", register="informal", modality="voice", label="phishing", persona="scammer", duration_sec=6,
    ),
    _s(
        "ru_vf_a004",
        "коллеги, конфиденциально, перевод на резервный счёт до конца дня, я на совещании",
        language="ru", register="formal", modality="voice", label="impersonation", persona="scammer",
        impersonates="ceo", alert_type="bec_intent", duration_sec=10,
    ),
]

EN_VOICE_MIXED = [
    _s("en_vf_l001", "yeah I checked, looks fine, lets talk tomorrow", language="en", register="informal", modality="voice", persona="lead", duration_sec=5),
    _s("en_vf_l002", "um can you resend the doc please", language="en", register="informal", modality="voice", persona="employee", duration_sec=4),
    _s("en_vf_l003", "Good afternoon, I confirm receipt of the contract.", language="en", register="formal", modality="voice", persona="legal", duration_sec=6),
    _s(
        "en_vf_a001",
        "hey its CEO new phone please wire fifty k today dont tell anyone",
        language="en", register="informal", modality="voice", label="impersonation", persona="scammer",
        impersonates="ceo", alert_type="bec_intent", duration_sec=7,
    ),
    _s(
        "en_vf_a002",
        "Dear employee, verify your account at the link within one hour to avoid suspension.",
        language="en", register="formal", modality="voice", label="phishing", persona="scammer", duration_sec=8,
    ),
]

EXTRA_VAL = [
    _s("ru_tf_l011", "Коллеги, отчёт по KPI за апрель выложен на портал.", language="ru", register="formal", persona="analytics", split="val"),
    _s("ru_ti_l011", "блин, упало прод, смотрю", language="ru", register="informal", persona="sre", split="val"),
    _s("en_ti_l009", "lol ok", language="en", register="informal", persona="intern", split="val"),
    _s(
        "ru_tf_a009",
        "Срочно! Перевод на счёт IBAN DE89… до 16:00. Это указание руководства.",
        language="ru", register="formal", label="impersonation", persona="scammer", split="val",
        alert_type="bec_intent",
    ),
    _s("ru_vf_l007", "ок, увидел, спасибо", language="ru", register="informal", modality="voice", split="val", duration_sec=3),
]

def all_samples() -> list[dict[str, Any]]:
    groups = [
        RU_FORMAL_LEGIT,
        RU_INFORMAL_LEGIT,
        EN_FORMAL_LEGIT,
        EN_INFORMAL_LEGIT,
        RU_FORMAL_ATTACK,
        RU_INFORMAL_ATTACK,
        EN_FORMAL_ATTACK,
        EN_INFORMAL_ATTACK,
        RU_VOICE_LEGIT,
        RU_VOICE_ATTACK,
        EN_VOICE_MIXED,
        EXTRA_VAL,
    ]
    out: list[dict[str, Any]] = []
    seen: set[str] = set()
    for g in groups:
        for item in g:
            if item["id"] in seen:
                raise ValueError(f"duplicate id {item['id']}")
            seen.add(item["id"])
            out.append(item)
    return out

def corpus_stats(samples: list[dict[str, Any]]) -> dict[str, Any]:
    from collections import Counter

    def key(*parts: str) -> str:
        return "/".join(parts)

    counts = Counter()
    for s in samples:
        counts[key(s["language"], s["register"], s["modality"], s["label"])] += 1
        counts[key("label", s["label"])] += 1
        counts[key("modality", s["modality"])] += 1
        counts[key("split", s.get("split", "train"))] += 1
    return {"total": len(samples), "breakdown": dict(sorted(counts.items()))}
