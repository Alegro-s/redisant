from __future__ import annotations

import re

from roza.config import Settings

# Теги вида <think>...</think> и <redacted_thinking>...</redacted_thinking> (без XML в исходнике — экранирование)
_RT_OPEN = "<" + "redacted_thinking" + ">"
_RT_CLOSE = "</" + "redacted_thinking" + ">"
_T_OPEN = "<" + "think" + ">"
_T_CLOSE = "</" + "think" + ">"

_THINK_BLOCKS = [
    re.compile(
        re.escape(_RT_OPEN) + r"[\s\S]*?" + re.escape(_RT_CLOSE),
        re.IGNORECASE | re.DOTALL,
    ),
    re.compile(
        re.escape(_T_OPEN) + r"[\s\S]*?" + re.escape(_T_CLOSE),
        re.IGNORECASE | re.DOTALL,
    ),
]

_CJK = re.compile(
    r"[\u3040-\u30ff\u3400-\u9fff\uf900-\ufaff\uff66-\uff9f]+",
)

# Типичные англ. «протечки» в ответах, которые должны быть по-русски
_CY = re.compile(r"[А-Яа-яЁё]")
_LAT = re.compile(r"[a-zA-Z]")
_EN_LEAK = re.compile(
    r"\b(?:"
    r"thy|thine|thee|thou|hath|doth|wherefore|wilt|shalt|"
    r"situation|perhaps|maybe|therefore|however|anyways?|btw"
    r")\b",
    re.IGNORECASE,
)


def _predominantly_cyrillic(text: str) -> bool:
    c = len(_CY.findall(text))
    l = len(_LAT.findall(text))
    return c >= 8 and c >= l


def sanitize_model_output(text: str, settings: Settings) -> str:
    if not text:
        return text
    t = text
    if settings.output_strip_thinking:
        for pat in _THINK_BLOCKS:
            t = pat.sub("", t)
        t = re.sub(re.escape(_RT_OPEN) + r"\s*", "", t, flags=re.I)
        t = re.sub(re.escape(_T_OPEN) + r"\s*", "", t, flags=re.I)
    if settings.output_strip_cjk:
        t = _CJK.sub(" ", t)
        t = re.sub(r" {2,}", " ", t)
        t = re.sub(r"\n{3,}", "\n\n", t)
    if settings.output_strip_en_leaks and _predominantly_cyrillic(t):
        t = _EN_LEAK.sub("", t)
        t = re.sub(r" {2,}", " ", t)
        t = re.sub(r"\s+([.,!?;:])", r"\1", t)
    return t.strip()
