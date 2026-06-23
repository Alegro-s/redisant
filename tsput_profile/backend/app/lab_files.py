from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent
_UPLOAD_ROOT = _ROOT / "data" / "lab_uploads"


def ensure_upload_dir(lab_id: str) -> Path:
    path = _UPLOAD_ROOT / lab_id
    path.mkdir(parents=True, exist_ok=True)
    return path


def save_submission_file(lab_id: str, filename: str, content: bytes) -> Path:
    folder = ensure_upload_dir(lab_id)
    safe_name = Path(filename).name or "submission.bin"
    dest = folder / safe_name
    dest.write_bytes(content)
    return dest


def read_submission_file(lab_id: str, filename: str) -> Path | None:
    path = _UPLOAD_ROOT / lab_id / Path(filename).name
    return path if path.is_file() else None
