import json
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import text
from sqlalchemy.orm import Session

EXPORT_DIR = Path("data/training")

def get_dataset_stats(db: Session) -> dict:
    total_messages = db.execute(text("SELECT COUNT(*) FROM messages")).scalar() or 0
    labeled = db.execute(text("SELECT COUNT(*) FROM training_labels")).scalar() or 0
    with_features = db.execute(text("SELECT COUNT(*) FROM message_features")).scalar() or 0
    analysis_runs = db.execute(text("SELECT COUNT(*) FROM analysis_runs")).scalar() or 0
    by_label = db.execute(
        text("SELECT label::text, COUNT(*) FROM training_labels GROUP BY label ORDER BY COUNT(*) DESC")
    ).all()
    return {
        "messages_total": total_messages,
        "labeled_count": labeled,
        "unlabeled_count": total_messages - labeled,
        "with_features_count": with_features,
        "analysis_runs_count": analysis_runs,
        "labels_breakdown": {row[0]: row[1] for row in by_label},
    }

def export_training_jsonl(db: Session, name: str = "export", only_labeled: bool = False) -> dict:
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.now(UTC).strftime("%Y%m%d_%H%M%S")
    filename = f"{name}_{ts}.jsonl"
    path = EXPORT_DIR / filename

    where = "WHERE training_label IS NOT NULL" if only_labeled else ""
    rows = db.execute(
        text(f"SELECT * FROM v_training_samples {where} ORDER BY message_at ASC")
    ).mappings().all()

    count = 0
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            record = dict(row)
            for key, val in list(record.items()):
                if hasattr(val, "isoformat"):
                    record[key] = val.isoformat()
                elif hasattr(val, "hex"):
                    record[key] = str(val)
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
            count += 1

    return {
        "file_path": str(path.as_posix()),
        "filename": filename,
        "record_count": count,
        "only_labeled": only_labeled,
    }
