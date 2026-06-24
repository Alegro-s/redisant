"""Очистка журнала админ-панели (audit_logs + messages + связанные записи)."""
from __future__ import annotations

import argparse
import json
import sys

from app.db.session import SessionLocal
from app.services.journal_cleanup import clear_admin_journal

def main() -> None:
    parser = argparse.ArgumentParser(description="Clear admin panel journal data")
    parser.add_argument("--keep-alerts", action="store_true", help="Do not delete alerts table")
    parser.add_argument("--keep-read-state", action="store_true", help="Keep chat_read_states")
    args = parser.parse_args()

    db = SessionLocal()
    try:
        stats = clear_admin_journal(
            db,
            include_alerts=not args.keep_alerts,
            include_chat_read=not args.keep_read_state,
        )
    finally:
        db.close()

    print(json.dumps(stats, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
