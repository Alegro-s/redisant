from __future__ import annotations

import logging
import threading

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.models import Message
from app.services.analysis import analyze_message
from app.services.message_crypto import resolve_message_plaintext

logger = logging.getLogger(__name__)

def count_pending_messages(db: Session) -> int:
    return (
        db.query(func.count(Message.id))
        .filter(Message.analysis_status.in_(("pending", "error")))
        .scalar()
        or 0
    )

def drain_pending_messages(db: Session, *, limit: int = 500, local_only: bool = True) -> dict:
    pending = (
        db.query(Message)
        .filter(Message.analysis_status.in_(("pending", "error")))
        .order_by(Message.created_at.asc())
        .limit(limit)
        .all()
    )
    done = 0
    errors = 0
    skipped = 0
    for msg in pending:
        if not resolve_message_plaintext(msg):
            skipped += 1
            continue
        try:
            analyze_message(db, msg, local_only=local_only)
            done += 1
        except Exception:
            logger.exception("pending analysis failed for message %s", msg.id)
            db.rollback()
            fresh = db.get(Message, msg.id)
            if fresh:
                fresh.analysis_status = "error"
                db.commit()
            errors += 1

    from app.services.dashboard import invalidate_dashboard_cache

    invalidate_dashboard_cache()
    remaining = count_pending_messages(db)
    return {"processed": done, "errors": errors, "skipped": skipped, "remaining": remaining}

def drain_pending_messages_background(*, limit: int = 500) -> None:
    def _run() -> None:
        from app.db.session import SessionLocal

        db = SessionLocal()
        try:
            stats = drain_pending_messages(db, limit=limit)
            logger.info("pending analysis drain: %s", stats)
        except Exception:
            logger.exception("pending analysis background drain failed")
        finally:
            db.close()

    threading.Thread(target=_run, daemon=True, name="pending-analysis").start()
