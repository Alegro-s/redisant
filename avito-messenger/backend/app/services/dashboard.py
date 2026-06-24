from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

import httpx
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db.models import Alert, AlertSeverity, AuditLog, Message, MessageFeatures, User, UserRole
from app.services.ai_client import ai_service_online as _ai_online
from app.services.ai_topology import build_ai_topology
from app.services.host_metrics import collect_host_load, collect_tokens, measure_db_latency_ms
from app.services.lm_studio_client import lm_studio_configured, lm_studio_status

_STARTUP = datetime.now(UTC)
_DETECTION_CACHE: tuple[float, bool] = (0.0, False)
_DASHBOARD_CACHE: tuple[float, dict] = (0.0, {})
_DASHBOARD_CACHE_TTL = 18.0

def _detection_ready() -> bool:
    import time

    global _DETECTION_CACHE
    now = time.time()
    if now - _DETECTION_CACHE[0] < 120:
        return _DETECTION_CACHE[1]
    ok = False
    try:
        from app.services.detection import pipeline as _pipeline

        ok = True
    except Exception:
        ok = False
    _DETECTION_CACHE = (now, ok)
    return ok

_LAYER_LABELS = (
    ("l1", "L1 Стилометрия"),
    ("l2", "L2 Семантика"),
    ("l3", "L3 Метаданные"),
    ("l4", "L4 Синтетика"),
    ("l5", "L5 Намерение"),
)

def _build_protection(
    l1: int,
    l2: int,
    l3: int,
    l4: int,
    l5: int,
    *,
    analyses_24h: int,
    pending: int,
    messages_total: int,
    mm_online: bool,
    db_online: bool,
    detection_ready: bool,
    lm_configured: bool,
    lm_online: bool,
    ai_configured: bool,
    ai_online: bool,
) -> dict:
    hits = [l1, l2, l3, l4, l5]
    total_hits = sum(hits)
    queue_ratio = pending / max(messages_total, 1)
    layers = []
    for i, (lid, label) in enumerate(_LAYER_LABELS):
        h = hits[i]
        share = round(h / total_hits * 100, 1) if total_hits else 0.0
        active_pct = round(min(h / max(analyses_24h, 1) * 100, 100), 1)
        if not detection_ready:
            health = 0
        elif pending > 0 or analyses_24h == 0:
            health = max(0, int(38 - queue_ratio * 35 - min(pending, 20)))
        else:
            coverage = min(analyses_24h, 1) / max(analyses_24h, 1)
            health = int(min(100, 55 + coverage * 25 + (25 if h >= 0 else 0)))
            if analyses_24h >= 3:
                health = int(min(100, 60 + active_pct * 0.35 + (15 if h > 0 else 10)))
        layers.append(
            {
                "id": lid,
                "label": label,
                "hits_24h": h,
                "share_pct": share,
                "active_pct": active_pct,
                "health_pct": health,
            }
        )

    checks: list[tuple[str, bool, float]] = [
        ("messenger", mm_online, 1.0),
        ("database", db_online, 1.0),
        ("detection", detection_ready, 1.5),
        ("queue_clear", pending == 0, 1.5),
        ("analyzed_24h", analyses_24h > 0, 1.0),
    ]
    if lm_configured:
        checks.append(("lm_studio", lm_online, 1.2))
    if ai_configured:
        checks.append(("ai_core", ai_online, 1.0))

    total_w = sum(weight for _, _, weight in checks)
    score = sum(weight for _, ok, weight in checks if ok) / total_w * 100 if total_w else 0.0
    if pending > 0:
        score = min(score, max(35, 78 - min(pending * 2, 40)))
    if lm_configured and not lm_online:
        score = min(score, 78)
    if messages_total > 0 and analyses_24h == 0:
        score = min(score, 45)

    infra = [mm_online, db_online, detection_ready, pending == 0]
    infra_pct = round(sum(1 for x in infra if x) / len(infra) * 100)
    layer_avg = round(sum(layer["health_pct"] for layer in layers) / len(layers)) if layers else 0
    overall = int(round(max(0, min(100, score))))
    core_online = detection_ready and pending == 0 and (not lm_configured or lm_online or ai_online)
    return {
        "overall_pct": overall,
        "core_online": core_online,
        "infra_pct": infra_pct,
        "layer_avg_pct": layer_avg,
        "pending": pending,
        "checks": [{"id": name, "ok": ok} for name, ok, _ in checks],
        "layers": layers,
    }

def invalidate_dashboard_cache() -> None:
    global _DASHBOARD_CACHE
    _DASHBOARD_CACHE = (0.0, {})

def _severity_to_level(severity: AlertSeverity) -> str:
    return severity.value

def _messenger_online() -> tuple[bool, int | None]:
    return True, 0

_DISPLAY_TZ = ZoneInfo("Europe/Moscow")

def _fmt_local(dt: datetime | None) -> str:
    if dt is None:
        return "—"
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    return dt.astimezone(_DISPLAY_TZ).strftime("%d.%m.%Y %H:%M")

def _journal_channel_label(m: Message) -> str:
    meta = m.metadata_ if isinstance(m.metadata_, dict) else {}
    if meta.get("client") == "caht_flutter":
        return "caht"
    return m.channel.value if m.channel else "unknown"

def build_dashboard(db: Session) -> dict:
    import time

    global _DASHBOARD_CACHE
    now_mono = time.time()
    if now_mono - _DASHBOARD_CACHE[0] < _DASHBOARD_CACHE_TTL and _DASHBOARD_CACHE[1]:
        cached = dict(_DASHBOARD_CACHE[1])
        cached.setdefault("meta", {})["cached"] = True
        return cached

    now = datetime.now(UTC)
    since_24h = now - timedelta(hours=24)
    settings = get_settings()

    users = db.query(User).all()
    messages_total = db.query(func.count(Message.id)).scalar() or 0
    messages_24h = (
        db.query(func.count(Message.id)).filter(Message.created_at >= since_24h).scalar() or 0
    )
    analyses_24h = (
        db.query(func.count(MessageFeatures.id))
        .filter(MessageFeatures.analyzed_at >= since_24h)
        .scalar()
        or 0
    )
    pending = (
        db.query(func.count(Message.id)).filter(Message.analysis_status == "pending").scalar() or 0
    )
    bytes_24h = (
        db.query(func.coalesce(func.sum(func.length(Message.body)), 0))
        .filter(Message.created_at >= since_24h)
        .scalar()
        or 0
    )

    alerts_all = db.query(Alert).order_by(Alert.created_at.desc()).limit(100).all()
    alerts_open = [a for a in alerts_all if not a.delivered]
    alerts_critical = [a for a in alerts_open if a.severity == AlertSeverity.critical]

    features_24h = (
        db.query(MessageFeatures).filter(MessageFeatures.analyzed_at >= since_24h).all()
    )
    avg_score = 0.0
    if features_24h:
        scores = [f.risk_score or 0 for f in features_24h]
        avg_score = round(sum(scores) / len(scores) * 100, 1)

    def _hit(f: MessageFeatures, key: str, fallback_fn) -> bool:
        lh = f.layer_hits or {}
        if key in lh:
            return bool(lh.get(key))
        return fallback_fn(f)

    l1 = sum(
        1
        for f in features_24h
        if _hit(f, "l1_stylometry", lambda x: x.style_similarity is not None and x.style_similarity < 0.68)
    )
    l2 = sum(1 for f in features_24h if _hit(f, "l2_embeddings", lambda _: False))
    l3 = sum(
        1
        for f in features_24h
        if _hit(f, "l3_metadata", lambda x: (x.metadata_anomaly_score or 0) > 0.28)
    )
    l4 = sum(1 for f in features_24h if _hit(f, "l4_ai_indicator", lambda x: (x.ai_score or 0) > 0.38))
    l5 = sum(1 for f in features_24h if _hit(f, "l5_intent", lambda _: False))

    mm_online, mm_latency = _messenger_online()
    db_online, db_latency = measure_db_latency_ms(db)
    host = collect_host_load()
    detection_ready = _detection_ready()

    ai_online, ai_latency = _ai_online()
    lm = lm_studio_status() if lm_studio_configured() else None
    if lm is None:
        from app.services.inference_gateway import GatewayStatus

        lm = GatewayStatus(False, False, None, "—", "", "не настроен", False)
    use_remote_ai = bool(settings.ai_service_url and settings.ai_service_url.strip())
    use_lm = lm_studio_configured()
    if use_lm and lm.online:
        core_online = True
        core_mode = "lm_studio_hybrid"
        core_latency = lm.latency_ms or ai_latency or 0
    elif use_remote_ai:
        core_online = ai_online
        core_mode = "ai_core_remote" if ai_online else "local_fallback"
        core_latency = ai_latency or 0
    else:
        core_online = detection_ready
        core_mode = "local_only"
        core_latency = 0

    t0 = datetime.now(UTC)
    gateway_latency = int((datetime.now(UTC) - t0).total_seconds() * 1000)

    role_labels = {
        UserRole.super_admin: "супер-админ",
        UserRole.admin: "админ",
        UserRole.user: "пользователь",
        UserRole.scammer: "мошенник",
    }

    user_payload = []
    msg_counts = {
        uid: int(cnt)
        for uid, cnt in db.query(Message.sender_id, func.count(Message.id)).group_by(Message.sender_id).all()
        if uid
    }
    for u in users:
        msg_count = msg_counts.get(u.id, 0)
        last_msg = (
            db.query(Message)
            .filter(Message.sender_id == u.id)
            .order_by(Message.created_at.desc())
            .first()
        )
        max_risk_row = (
            db.query(func.max(MessageFeatures.risk_score))
            .join(Message, Message.id == MessageFeatures.message_id)
            .filter(Message.sender_id == u.id)
            .scalar()
        )
        risk = int((max_risk_row or 0) * 100)
        if u.role in (UserRole.admin, UserRole.super_admin):
            risk = 0
        last_seen = _fmt_local(last_msg.created_at) if last_msg else None
        caht_msgs = (
            db.query(func.count(Message.id))
            .filter(
                Message.sender_id == u.id,
                Message.metadata_.contains({"client": "caht_flutter"}),
            )
            .scalar()
            or 0
        )
        chat_linked = caht_msgs > 0 or msg_count > 0
        user_payload.append(
            {
                "id": u.username,
                "name": u.display_name,
                "role": role_labels.get(u.role, u.role.value),
                "channel": "caht",
                "risk": risk,
                "messages_count": msg_count,
                "last_seen": last_seen,
                "status": "blocked" if u.is_blocked else "active",
                "block_reason": u.block_reason,
                "can_block": u.role not in (UserRole.admin, UserRole.super_admin),
                "mattermost_linked": chat_linked,
                "chat_linked": chat_linked,
            }
        )

    mm_linked_count = sum(1 for u in user_payload if u.get("chat_linked"))

    alert_payload = []
    for a in alerts_all[:50]:
        related_user = ""
        if a.related_message_ids:
            msg = db.get(Message, a.related_message_ids[0])
            if msg and msg.sender_id:
                sender = db.get(User, msg.sender_id)
                related_user = sender.username if sender else ""
        score = 70
        if a.related_message_ids:
            feat = (
                db.query(MessageFeatures)
                .filter(MessageFeatures.message_id == a.related_message_ids[0])
                .first()
            )
            if feat and feat.risk_score is not None:
                score = int(feat.risk_score * 100)
        alert_payload.append(
            {
                "time": _fmt_local(a.created_at),
                "level": _severity_to_level(a.severity),
                "score": score,
                "user": related_user or "—",
                "channel": "caht",
                "rule": a.alert_type,
                "signal": a.title_ru,
                "status": "closed" if a.delivered else "open",
            }
        )

    journal = []
    for log in db.query(AuditLog).order_by(AuditLog.created_at.desc()).limit(20).all():
        action_ru = {
            "user_blocked": "Блокировка",
            "user_unblocked": "Разблокировка",
        }.get(log.action, log.action)
        journal.append(
            {
                "time": _fmt_local(log.created_at),
                "type": action_ru,
                "text": f"{log.target_username}: {log.details or ''}",
            }
        )
    for m in db.query(Message).order_by(Message.created_at.desc()).limit(30).all():
        sender_name = "?"
        if m.sender_id:
            s = db.get(User, m.sender_id)
            sender_name = s.username if s else "?"
        feat = db.query(MessageFeatures).filter(MessageFeatures.message_id == m.id).first()
        if m.analysis_status == "done" and feat and feat.risk_score is not None:
            risk_pct = int(feat.risk_score * 100)
            entry_type = f"риск {risk_pct}%"
            if feat.risk_score >= 0.42:
                entry_type = f"⚠ {entry_type}"
        elif m.analysis_status == "error":
            entry_type = "ошибка анализа"
        else:
            entry_type = m.analysis_status or m.analysis_source or "pending"
        journal.append(
            {
                "time": _fmt_local(m.created_at),
                "type": entry_type,
                "text": f"[{_journal_channel_label(m)}] {sender_name}: {m.body[:100]}",
            }
        )

    protection = _build_protection(
        l1,
        l2,
        l3,
        l4,
        l5,
        analyses_24h=analyses_24h,
        pending=pending,
        messages_total=messages_total,
        mm_online=mm_online,
        db_online=db_online,
        detection_ready=detection_ready,
        lm_configured=use_lm,
        lm_online=lm.online,
        ai_configured=use_remote_ai,
        ai_online=ai_online,
    )

    topology = build_ai_topology(
        messenger_online=mm_online,
        gateway_online=True,
        db_online=db_online,
        detection_ready=detection_ready,
        messenger_latency=mm_latency,
        gateway_latency=gateway_latency,
        db_latency=db_latency,
        gw_status=lm,
    )

    result = {
        "meta": {
            "server_time": now.isoformat(),
            "uptime_sec": int((now - _STARTUP).total_seconds()),
            "version": "0.3.0",
            "host": settings.api_host,
        },
        "load": {
            **host,
            "queue": pending,
            "latency_ms": db_latency,
        },
        "traffic": {
            "messages_total": messages_total,
            "messages_per_min": round(messages_24h / (24 * 60), 2) if messages_24h else 0.0,
            "analyses_pending": pending,
            "analyses_24h": analyses_24h,
            "bytes_in_24h": int(bytes_24h),
        },
        "security": {
            "alerts_open": len(alerts_open),
            "alerts_critical": len(alerts_critical),
            "blocks_active": sum(1 for u in users if u.is_blocked),
            "users_total": len(users),
            "users_blocked": sum(1 for u in users if u.is_blocked),
            "users_high_risk": sum(1 for u in user_payload if u["risk"] >= 65),
        },
        "detection": {
            "l1_hits_24h": l1,
            "l2_hits_24h": l2,
            "l3_hits_24h": l3,
            "l4_hits_24h": l4,
            "l5_hits_24h": l5,
            "avg_score_24h": avg_score,
        },
        "protection": protection,
        "topology": topology,
        "tokens": collect_tokens(),
        "services": {
            "messenger": {
                "online": mm_online,
                "latency_ms": mm_latency or 0,
                "uptime_sec": int((now - _STARTUP).total_seconds()),
                "users_linked": mm_linked_count,
                "users_total": len(users),
            },
            "gateway": {
                "online": lm.online if use_lm else True,
                "latency_ms": lm.latency_ms or gateway_latency,
                "uptime_sec": int((now - _STARTUP).total_seconds()),
            },
            "core": {
                "online": core_online,
                "latency_ms": core_latency,
                "uptime_sec": 0,
                "mode": core_mode,
            },
            "database": {
                "online": db_online,
                "latency_ms": db_latency,
                "uptime_sec": int((now - _STARTUP).total_seconds()),
            },
            "lm_studio": {
                "online": lm.online if use_lm else False,
                "configured": use_lm,
                "latency_ms": lm.latency_ms or 0,
                "host": lm.host,
                "model": lm.model,
                "uptime_sec": 0,
            },
            "explain": {
                "online": (lm.online if use_lm else False) or (ai_online if use_remote_ai else core_online),
                "latency_ms": lm.latency_ms or ai_latency or core_latency,
                "uptime_sec": 0,
            },
        },
        "users": user_payload,
        "alerts": alert_payload,
        "journal": journal,
    }
    _DASHBOARD_CACHE = (now_mono, result)
    return result
