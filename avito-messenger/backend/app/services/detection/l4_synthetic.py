import re
from pathlib import Path

import numpy as np

POLITE = (
    "пожалуйста",
    "будьте добры",
    "уважаемый",
    "здравствуйте",
    "благодарю",
    "коллега",
    "прошу",
)
FORMAL = ("настоящим", "сообщаем", "информируем", "в соответствии", "довожу до сведения")

_CLF_PATH = Path(__file__).resolve().parents[3] / "data" / "models" / "text_synthetic_v1.joblib"
_clf = None

def _load_clf():
    global _clf
    if _clf is not None:
        return _clf
    if not _CLF_PATH.is_file():
        _clf = False
        return _clf
    try:
        import joblib

        _clf = joblib.load(_CLF_PATH)
    except Exception:
        _clf = False
    return _clf

def _heuristic(text: str, metadata: dict) -> tuple[float, dict]:
    low = text.lower()
    words = re.findall(r"[a-zA-Zа-яА-ЯёЁ0-9]+", text)
    polite_hits = sum(1 for p in POLITE if p in low)
    formal_hits = sum(1 for f in FORMAL if f in low)
    avg_len = sum(len(w) for w in words) / max(len(words), 1)

    score = 0.0
    if polite_hits >= 2:
        score += 0.45
    elif polite_hits == 1:
        score += 0.18
    if formal_hits:
        score += 0.28
    if avg_len > 6.2:
        score += 0.18
    if len(words) > 16:
        score += 0.12

    traits = metadata.get("style_traits") or {}
    if traits.get("short_messages") and len(words) > 12:
        score += 0.2

    username = (metadata.get("user_name") or "").lower()
    if username in ("ceo", "user2") and score > 0.28:
        score = min(1.0, score + 0.12)

    return min(score, 1.0), {"polite_hits": polite_hits, "mode": "heuristic"}

def analyze_l4(text: str, metadata: dict) -> tuple[float, int, dict]:
    model = _load_clf()
    if model and model is not False:
        try:
            pipe = model.get("pipeline") if isinstance(model, dict) else model
            if pipe is not None:
                proba = pipe.predict_proba([text])[0]
                classes = list(pipe.classes_)
                idx = classes.index("synthetic") if "synthetic" in classes else int(np.argmax(proba))
                score = float(proba[idx])
                hit = 1 if score >= 0.42 else 0
                return score, hit, {"ai_score": score, "mode": "classifier"}
        except Exception:
            pass

    score, extra = _heuristic(text, metadata)
    hit = 1 if score >= 0.36 else 0
    return score, hit, {"ai_score": score, **extra}
