from __future__ import annotations

import json
import sys
from pathlib import Path

def _runtime_roots() -> tuple[Path, Path | None]:
    """Docker: /app + volume data/. Local dev: repo root + backend/ai-core paths."""
    if Path("/app/app").is_dir():
        root = Path("/app")
        return root / "data" / "models" / "risk_fusion_v1.joblib", None
    repo = Path(__file__).resolve().parents[3]
    return (
        repo / "backend" / "data" / "models" / "risk_fusion_v1.joblib",
        repo / "ai-core" / "data" / "models" / "risk_fusion_v1.joblib",
    )


def _data_root() -> Path:
    if Path("/app/app").is_dir():
        return Path("/app") / "data"
    return Path(__file__).resolve().parents[3] / "data"


REPO = Path(__file__).resolve().parents[3]
if not Path("/app/app").is_dir():
    sys.path.insert(0, str(REPO / "backend"))

import joblib
import numpy as np
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.model_selection import train_test_split

from app.services.detection.l1_stylometry import analyze_l1
from app.services.detection.l2_semantic import analyze_l2
from app.services.detection.l3_metadata import analyze_l3
from app.services.detection.l4_synthetic import analyze_l4
from app.services.detection.l5_intent import analyze_l5
from app.services.detection.intent_entities import extract_intent_entities
from app.services.detection.l6_voice import analyze_l6

_DATA = _data_root()
CORPUS = _DATA / "training" / "corpus" / "classification_v1.jsonl"
SYNTHETIC = _DATA / "training" / "corpus" / "synthetic_text_v1.jsonl"
OUT_BACKEND, OUT_CORE = _runtime_roots()

def _rows_from_corpus(path: Path) -> list[tuple[str, str, dict]]:
    out: list[tuple[str, str, dict]] = []
    if not path.is_file():
        return out
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            text = row.get("text") or ""
            label = row.get("label") or "legit"
            meta = {"username": row.get("username") or "ceo", "user_name": row.get("username") or "ceo"}
            if label in ("phishing", "impersonation", "ai_generated", "suspicious"):
                y = "phishing"
            else:
                y = "legit"
            out.append((text, y, meta))
    return out

def _feature_vector(text: str, meta: dict) -> list[float]:
    style_sim, l1_hit, _ = analyze_l1(text, meta)
    emb_sim, l2_hit, _ = analyze_l2(text, meta)
    meta_score, l3_hit, _ = analyze_l3(text, meta)
    ai_score, l4_hit, _ = analyze_l4(text, meta)
    intent_score, l5_hit, _ = analyze_l5(text, meta)
    ent_score, ent_hit, _ = extract_intent_entities(text, meta)
    voice_score, l6_hit, _ = analyze_l6(None)
    layer_scores = {
        "l1": 1.0 - style_sim,
        "l2": 1.0 - emb_sim,
        "l3": meta_score,
        "l4": ai_score,
        "l5": max(intent_score, ent_score),
        "l6": voice_score,
    }
    layer_hits = {
        "l1_stylometry": l1_hit,
        "l2_embeddings": l2_hit,
        "l3_metadata": l3_hit,
        "l4_ai_indicator": l4_hit,
        "l5_intent": 1 if (l5_hit or ent_hit) else 0,
        "l6_voice": l6_hit,
    }
    return [
        float(layer_scores["l1"]),
        float(layer_scores["l2"]),
        float(layer_scores["l3"]),
        float(layer_scores["l4"]),
        float(layer_scores["l5"]),
        float(layer_scores["l6"]),
        float(layer_hits["l1_stylometry"]),
        float(layer_hits["l2_embeddings"]),
        float(layer_hits["l3_metadata"]),
        float(layer_hits["l4_ai_indicator"]),
        float(layer_hits["l5_intent"]),
        float(layer_hits["l6_voice"]),
        0.0,
        1.0,
    ]

def main() -> None:
    rows = _rows_from_corpus(CORPUS) + _rows_from_corpus(SYNTHETIC)
    if len(rows) < 8:
        rows.extend(
            [
                ("Уважаемый коллега, срочно переведите средства на счёт.", "phishing", {"username": "scammer1"}),
                ("ок сделаю", "legit", {"username": "ceo"}),
                ("Прошу конфиденциально перевести до конца дня", "phishing", {"username": "scammer1"}),
                ("гляну завтра", "legit", {"username": "ceo"}),
            ]
        )
    X: list[list[float]] = []
    y: list[str] = []
    for text, label, meta in rows:
        X.append(_feature_vector(text, meta))
        y.append(label)
    X_arr = np.array(X, dtype=float)
    clf = GradientBoostingClassifier(random_state=42)
    if len(set(y)) > 1 and len(y) >= 10:
        X_train, X_test, y_train, y_test = train_test_split(X_arr, y, test_size=0.2, random_state=42, stratify=y)
        clf.fit(X_train, y_train)
    else:
        clf.fit(X_arr, y)
    bundle = {"pipeline": clf, "labels": sorted(set(y)), "n_samples": len(y)}
    OUT_BACKEND.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(bundle, OUT_BACKEND)
    if OUT_CORE is not None:
        OUT_CORE.parent.mkdir(parents=True, exist_ok=True)
        joblib.dump(bundle, OUT_CORE)
    print(str(OUT_BACKEND))

if __name__ == "__main__":
    main()
