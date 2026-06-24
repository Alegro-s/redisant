import time
from datetime import UTC, datetime

import httpx
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import get_settings
from app.services.ai_client import ai_service_online
from app.services.lm_studio_client import lm_studio_configured, lm_studio_status
from app.services.dashboard import build_dashboard
from app.services.detection.qa import run_qa
from app.services.host_metrics import collect_host_load

def _check(cid: str, group: str, ok: bool, detail: str, ms: int = 0) -> dict:
    return {"id": cid, "group": group, "ok": ok, "ms": ms, "detail": detail}

def run_system_test(db: Session) -> dict:
    settings = get_settings()
    checks: list[dict] = []

    t0 = time.perf_counter()
    try:
        db.execute(text("SELECT 1"))
        checks.append(_check("postgres", "infra", True, "SELECT 1 OK", int((time.perf_counter() - t0) * 1000)))
    except Exception as exc:
        checks.append(_check("postgres", "infra", False, str(exc), int((time.perf_counter() - t0) * 1000)))

    host = collect_host_load()
    checks.append(
        _check(
            "host_cpu",
            "server",
            host["cpu"] < 95,
            f"CPU {host['cpu']}%",
            0,
        )
    )
    checks.append(
        _check(
            "host_ram",
            "server",
            host["ram"] < 95,
            f"RAM {host['ram']}%",
            0,
        )
    )

    qa = run_qa()
    for c in qa.get("checks", []):
        checks.append(
            _check(
                f"local_{c.get('id')}",
                c.get("group", "layers"),
                bool(c.get("ok")),
                str(c.get("detail", "")),
                int(c.get("ms") or 0),
            )
        )
    checks.append(
        _check(
            "local_qa_bundle",
            "layers",
            bool(qa.get("ok")),
            f"passed={qa.get('summary', {}).get('passed')}/{qa.get('summary', {}).get('total')}",
            0,
        )
    )

    use_remote = bool(settings.ai_service_url and settings.ai_service_url.strip())
    ai_on, ai_lat = ai_service_online()
    use_lm = lm_studio_configured()
    lm = lm_studio_status()
    if use_lm:
        checks.append(
            _check(
                "lm_studio",
                "ai",
                lm.online,
                f"{lm.host or 'LM Studio'} · {lm.detail}" if lm.configured else "не настроен",
                lm.latency_ms or 0,
            )
        )
    else:
        checks.append(
            _check(
                "lm_studio",
                "ai",
                True,
                "не настроен (локальные L1–L5)",
                0,
            )
        )
    if use_remote:
        checks.append(
            _check(
                "ai_core_remote",
                "infra",
                ai_on,
                "удалённый Core" if ai_on else "офлайн",
                ai_lat or 0,
            )
        )
    else:
        checks.append(
            _check(
                "ai_core_remote",
                "infra",
                True,
                "не используется (локальные L1–L5)",
                0,
            )
        )
        checks.append(
            _check(
                "detection_local",
                "infra",
                bool(qa.get("ok")),
                "локальные L1–L5",
                0,
            )
        )

    dash = build_dashboard(db)
    protection = dash.get("protection") or {}
    checks.append(
        _check(
            "readiness",
            "protection",
            protection.get("overall_pct", 0) >= 50,
            f"готовность {protection.get('overall_pct', 0)}%",
            0,
        )
    )
    for layer in protection.get("layers") or []:
        checks.append(
            _check(
                f"layer_{layer.get('id')}",
                "protection",
                (layer.get("health_pct") or 0) >= 40,
                f"{layer.get('label')}: {layer.get('hits_24h')} сраб., health {layer.get('health_pct')}%",
                0,
            )
        )

    checks.append(
        _check(
            "dashboard",
            "panel",
            "protection" in dash and "users" in dash,
            "dashboard ok",
            0,
        )
    )

    mm = dash.get("services", {}).get("messenger") or {}
    checks.append(
        _check(
            "mattermost",
            "infra",
            bool(mm.get("online")),
            f"ping, связано {mm.get('users_linked', 0)}/{mm.get('users_total', 0)}",
            int(mm.get("latency_ms") or 0),
        )
    )

    if settings.mattermost_url:
        t0 = time.perf_counter()
        try:
            with httpx.Client(timeout=5) as client:
                res = client.get(f"{settings.mattermost_url.rstrip('/')}/api/v4/system/ping")
                if not mm.get("online"):
                    checks.append(
                        _check(
                            "mattermost_ping",
                            "infra",
                            res.status_code == 200,
                            "ping ok" if res.status_code == 200 else f"HTTP {res.status_code}",
                            int((time.perf_counter() - t0) * 1000),
                        )
                    )
        except Exception as exc:
            if not mm.get("online"):
                checks.append(_check("mattermost_ping", "infra", False, str(exc), 0))

    passed = sum(1 for c in checks if c["ok"])
    failed = len(checks) - passed
    return {
        "ok": failed == 0,
        "finished_at": datetime.now(UTC).isoformat(),
        "summary": {"passed": passed, "failed": failed, "total": len(checks)},
        "checks": checks,
        "readiness": {
            "overall_pct": protection.get("overall_pct", 0),
            "infra_pct": protection.get("infra_pct", 0),
            "core_online": protection.get("core_online", False),
            "protection": protection,
            "load": dash.get("load"),
            "traffic": dash.get("traffic"),
            "detection": dash.get("detection"),
            "services": dash.get("services"),
            "topology": dash.get("topology"),
            "host": host,
        },
    }
