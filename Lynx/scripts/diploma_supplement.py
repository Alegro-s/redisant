# -*- coding: utf-8 -*-
"""Extract unique paragraphs from engine draft — no duplicates."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SRC = ROOT / "Lynx" / "docs" / "DIPLOMA_LYNX_2D_ENGINE.md"
EXPAND = ROOT / "Lynx" / "docs" / "DIPLOMA_LYNX_2D_ENGINE_EXPAND.md"


def _normalize(p: str) -> str:
    p = re.sub(r"\s+", " ", p.strip())
    return p[:200]  # fingerprint


def extract_paragraphs(path: Path) -> list[str]:
    if not path.exists():
        return []
    raw = path.read_text(encoding="utf-8")
    parts = re.split(r"\n\n+", raw)
    out: list[str] = []
    for p in parts:
        p = p.strip()
        if len(p) < 80:
            continue
        if p.startswith("#") or p.startswith(">") or p.startswith("```"):
            continue
        if p.startswith("|") or p.startswith("---"):
            continue
        if p.startswith("*Рисунок") or p.startswith("МИНПРОСВЕЩЕНИЯ"):
            continue
        # skip markdown tables (multiple | lines)
        if p.count("|") > 4 and "\n|" in p:
            continue
        out.append(p)
    return out


def _core_fingerprints(existing: str) -> set[str]:
    import re

    parts = re.split(r"\n\n+", existing)
    return {_normalize(p) for p in parts if len(p.strip()) > 60}


def gen_supplement(existing: str, sanitize) -> str:
    """Append draft paragraphs that are not verbatim copies of core text."""
    paras: list[str] = []
    for path in (SRC, EXPAND):
        paras.extend(extract_paragraphs(path))

    core_fp = _core_fingerprints(existing)
    seen: set[str] = set()
    blocks: list[str] = []

    for p in paras:
        key = _normalize(p)
        if key in seen or key in core_fp:
            continue
        seen.add(key)
        blocks.append(sanitize(p))

    if not blocks:
        return ""

    s = "\n\n# ДОПОЛНИТЕЛЬНЫЕ РАЗДЕЛЫ (уникальные материалы)\n\n"
    theory, practice, test = [], [], []
    for b in blocks:
        low = b.lower()
        if any(w in low for w in ("тест", "регресс", "сценари", "альфа", "cargo", "flutter test", "метрик")):
            test.append(b)
        elif any(
            w in low
            for w in (
                "проект",
                "редактор",
                "ffi",
                "экспорт",
                "реализ",
                "диаграм",
                "тайл",
                "platformer",
                "flutter",
                "rust",
                "симуляц",
                "клиент",
            )
        ):
            practice.append(b)
        else:
            theory.append(b)

    if theory:
        s += "## Дополнение к главе 1\n\n" + "\n\n".join(theory) + "\n\n"
    if practice:
        s += "## Дополнение к главе 2\n\n" + "\n\n".join(practice) + "\n\n"
    if test:
        s += "## Дополнение к главе 3\n\n" + "\n\n".join(test) + "\n\n"
    return s
