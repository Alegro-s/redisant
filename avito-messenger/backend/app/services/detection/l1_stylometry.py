import re

import numpy as np

from app.services.detection.profiles import load_profiles

FEATURE_KEYS = (
    "avg_word_len",
    "exclamation_rate",
    "question_rate",
    "uppercase_rate",
    "polite_rate",
)

def features(text: str) -> dict[str, float]:
    words = re.findall(r"[a-zA-Zа-яА-ЯёЁ0-9]+", text)
    if not words:
        return {k: 0.0 for k in FEATURE_KEYS}
    polite = ("пожалуйста", "будьте добры", "уважаемый", "здравствуйте", "благодарю", "коллега")
    low = text.lower()
    return {
        "avg_word_len": sum(len(w) for w in words) / len(words),
        "exclamation_rate": text.count("!") / max(len(text), 1),
        "question_rate": text.count("?") / max(len(text), 1),
        "uppercase_rate": sum(1 for c in text if c.isupper()) / max(len(text), 1),
        "polite_rate": sum(1 for p in polite if p in low) / max(len(words), 1),
    }

def _vec(feat: dict) -> np.ndarray:
    return np.array([feat[k] for k in FEATURE_KEYS], dtype=float)

def _distance(a: dict, b: dict) -> float:
    va, vb = _vec(a), _vec(b)
    denom = np.linalg.norm(va) * np.linalg.norm(vb)
    if denom < 1e-9:
        return 1.0
    return 1.0 - float(np.dot(va, vb) / denom)

def profile_from_db_traits(traits: dict | None, reference: dict | None) -> dict:
    base = features("ок сделаю завтра")
    if traits:
        if traits.get("short_messages"):
            base["avg_word_len"] = 4.0
        if traits.get("uses_exclamation") is False:
            base["exclamation_rate"] = 0.02
        if traits.get("signature"):
            base["polite_rate"] = 0.05
    if reference and reference.get("avg_words"):
        base["avg_word_len"] = float(reference["avg_words"]) / 2
    if reference and reference.get("politeness") is not None:
        base["polite_rate"] = float(reference["politeness"])
    return base

def analyze_l1(text: str, metadata: dict) -> tuple[float, int, dict]:
    feat = features(text)
    profiles = load_profiles()
    username = (metadata.get("user_name") or metadata.get("username") or "").lower()

    if metadata.get("style_traits") or metadata.get("style_reference"):
        target = profile_from_db_traits(metadata.get("style_traits"), metadata.get("style_reference"))
    else:
        target = profiles.get(username) or profiles.get("ceo")

    ref = profiles.get("scammer_ref")
    ceo_prof = profiles.get("ceo")
    if metadata.get("style_traits") and username == "ceo":
        target = profile_from_db_traits(metadata.get("style_traits"), metadata.get("style_reference"))

    sim_sender = 1.0 - _distance(feat, target) if target else 0.5
    sim_ceo = 1.0 - _distance(feat, ceo_prof) if ceo_prof else 0.5
    sim_scam = 1.0 - _distance(feat, ref) if ref else 0.0

    impersonates = metadata.get("impersonates_username") or metadata.get("impersonates")
    style_similarity = sim_sender
    if impersonates or (sim_ceo > 0.72 and username not in ("ceo",)):
        style_similarity = max(sim_ceo * 0.9, sim_scam * 0.55)

    anomaly = 1.0 - style_similarity
    hit = 1 if anomaly >= 0.32 or (sim_scam > 0.68 and username not in ("scammer1", "scammer2", "scammer3")) else 0
    return style_similarity, hit, {"features": feat, "style_similarity": style_similarity}
