import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

from app.services.core_client import embed_text_remote
from app.services.detection.profiles import load_profiles

_VECTORIZER: TfidfVectorizer | None = None
_CACHE_KEY: tuple[str, ...] | None = None
_REF_MATRIX = None

def _tfidf_similarity(text: str, samples: list[str]) -> tuple[float, str]:
    global _VECTORIZER, _CACHE_KEY, _REF_MATRIX
    if not samples:
        samples = ["тестовое сообщение"]
    key = tuple(samples)
    if _VECTORIZER is None or _CACHE_KEY != key:
        _VECTORIZER = TfidfVectorizer(max_features=3000, ngram_range=(1, 2))
        _REF_MATRIX = _VECTORIZER.fit_transform(samples)
        _CACHE_KEY = key
    q = _VECTORIZER.transform([text])
    sims = cosine_similarity(q, _REF_MATRIX)[0]
    sim = float(np.max(sims)) if len(sims) else 0.5
    return sim, "tfidf"

def analyze_l2(text: str, metadata: dict) -> tuple[float, int, dict]:
    profiles = load_profiles()
    username = (metadata.get("user_name") or metadata.get("username") or "ceo").lower()
    prof = profiles.get(username) or profiles.get("ceo") or {}
    samples = list(prof.get("samples") or [])
    if metadata.get("corpus_samples"):
        samples = list(metadata["corpus_samples"])[:200]

    remote = embed_text_remote(text, samples)
    if remote and "similarity" in remote:
        sim = float(remote["similarity"])
        mode = str(remote.get("mode") or "embedding")
    else:
        sim, mode = _tfidf_similarity(text, samples)

    hit = 1 if sim < 0.38 else 0
    return sim, hit, {"semantic_similarity": sim, "mode": mode}
