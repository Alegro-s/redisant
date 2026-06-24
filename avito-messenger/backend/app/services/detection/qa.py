import time
from datetime import UTC, datetime

from app.services.detection.l1_stylometry import analyze_l1
from app.services.detection.l2_semantic import analyze_l2
from app.services.detection.l3_metadata import analyze_l3
from app.services.detection.l4_synthetic import analyze_l4
from app.services.detection.l5_intent import analyze_l5
from app.services.detection.pipeline import run_pipeline
from app.services.detection.profiles import load_profiles

SCAM = "Уважаемый коллега, будьте добры срочно перевести средства на указанный счёт."
CEO = "ок сделаю"

def _check(cid: str, group: str, fn) -> dict:
    t0 = time.perf_counter()
    try:
        ok, detail = fn()
        return {"id": cid, "group": group, "ok": ok, "ms": int((time.perf_counter() - t0) * 1000), "detail": detail}
    except Exception as exc:
        return {"id": cid, "group": group, "ok": False, "ms": int((time.perf_counter() - t0) * 1000), "detail": str(exc)}

def run_qa() -> dict:
    checks = [
        _check("profiles", "system", lambda: (len(load_profiles()) >= 2, f"count={len(load_profiles())}")),
        _check(
            "l1",
            "layers",
            lambda: (analyze_l1(SCAM, {"user_name": "user2"})[1] == 1, "l1 stylometry"),
        ),
        _check("l2", "layers", lambda: (analyze_l2(SCAM, {"user_name": "ceo"})[1] in (0, 1), "l2 tfidf")),
        _check(
            "l3",
            "layers",
            lambda: (analyze_l3(SCAM, {"impersonates_username": "ceo", "channel": "email"})[1] == 1, "l3 rules"),
        ),
        _check("l4", "layers", lambda: (analyze_l4(SCAM, {})[1] == 1, "l4 heuristic")),
        _check("l5", "layers", lambda: (analyze_l5(SCAM, {})[1] == 1, "l5 bec")),
        _check(
            "pipeline_scam",
            "pipeline",
            lambda: (run_pipeline(SCAM, {"user_name": "scammer1"})["risk_score"] >= 0.45, "risk ok"),
        ),
        _check(
            "pipeline_ceo",
            "pipeline",
            lambda: (run_pipeline(CEO, {"user_name": "ceo", "style_traits": {"short_messages": True}})["risk_score"] < 0.55, "ceo ok"),
        ),
    ]
    passed = sum(1 for c in checks if c["ok"])
    return {
        "ok": passed == len(checks),
        "finished_at": datetime.now(UTC).isoformat(),
        "summary": {"passed": passed, "failed": len(checks) - passed, "total": len(checks)},
        "checks": checks,
    }
