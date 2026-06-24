from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.db.models import AuditLog

def log_auth_event(
    db: Session,
    *,
    action: str,
    actor_username: str,
    target_username: str | None = None,
    details: str | None = None,
) -> None:
    db.add(
        AuditLog(
            id=uuid.uuid4(),
            action=action,
            target_username=target_username or actor_username,
            actor_username=actor_username,
            details=details,
        )
    )
