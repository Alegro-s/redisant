from datetime import datetime
from typing import Any

import httpx

from .config import settings
from .schemas import (
    ExamItem,
    GradeItem,
    LabCommentItem,
    LabItem,
    PortfolioItem,
    ScheduleItem,
)

def _enabled() -> bool:
    return bool(settings.supabase_url.strip() and settings.supabase_anon_key.strip())

def _headers() -> dict[str, str]:
    key = settings.supabase_anon_key.strip()
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

def _base() -> str:
    return settings.supabase_url.rstrip("/") + "/rest/v1"

def _get(table: str, *, order: str = "updated_at.desc") -> list[dict[str, Any]] | None:
    if not _enabled():
        return None
    url = f"{_base()}/{table}?order={order}"
    try:
        with httpx.Client(timeout=12.0) as client:
            r = client.get(url, headers=_headers())
            if r.status_code >= 400:
                return None
            data = r.json()
            return data if isinstance(data, list) else None
    except httpx.HTTPError:
        return None

def _upsert(table: str, rows: list[dict[str, Any]]) -> bool:
    if not _enabled() or not rows:
        return False
    url = f"{_base()}/{table}"
    headers = {**_headers(), "Prefer": "resolution=merge-duplicates,return=minimal"}
    try:
        with httpx.Client(timeout=20.0) as client:
            r = client.post(url, headers=headers, json=rows)
            return r.status_code < 400
    except httpx.HTTPError:
        return False

def _delete_all(table: str) -> bool:
    if not _enabled():
        return False
    url = f"{_base()}/{table}?id=neq.__never__"
    try:
        with httpx.Client(timeout=20.0) as client:
            r = client.delete(url, headers=_headers())
            return r.status_code < 400
    except httpx.HTTPError:
        return False

def fetch_schedule() -> list[ScheduleItem] | None:
    rows = _get("tspu_schedule", order="start_time.asc")
    if rows is None:
        return None
    out: list[ScheduleItem] = []
    for row in rows:
        out.append(
            ScheduleItem(
                id=str(row["id"]),
                subject=row["subject"],
                teacher=row.get("teacher") or "",
                classroom=row.get("classroom") or "",
                startTime=datetime.fromisoformat(str(row["start_time"]).replace("Z", "+00:00")),
                endTime=datetime.fromisoformat(str(row["end_time"]).replace("Z", "+00:00")),
                type=row.get("type") or "лекция",
            )
        )
    return out

def save_schedule(items: list[ScheduleItem]) -> bool:
    payload = [
        {
            "id": i.id,
            "subject": i.subject,
            "teacher": i.teacher,
            "classroom": i.classroom,
            "start_time": i.startTime.isoformat(),
            "end_time": i.endTime.isoformat(),
            "type": i.type,
            "updated_at": datetime.utcnow().isoformat() + "Z",
        }
        for i in items
    ]
    if not _delete_all("tspu_schedule"):
        return False
    return _upsert("tspu_schedule", payload)

def fetch_grades() -> list[GradeItem] | None:
    rows = _get("tspu_grades", order="date.desc")
    if rows is None:
        return None
    out: list[GradeItem] = []
    for row in rows:
        out.append(
            GradeItem(
                id=str(row["id"]),
                subject=row["subject"],
                teacher=row.get("teacher") or "",
                value=int(row.get("value") or 0),
                type=row["type"],
                date=datetime.fromisoformat(str(row["date"]).replace("Z", "+00:00")),
                semester=row.get("semester"),
                zet=row.get("zet"),
                hours=row.get("hours"),
                gradeLabel=row.get("grade_label"),
            )
        )
    return out

def fetch_exams() -> list[ExamItem] | None:
    rows = _get("tspu_exams")
    if rows is None:
        return None
    return [
        ExamItem(
            id=str(r["id"]),
            subject=r["subject"],
            teacher=r.get("teacher") or "",
            date=r["exam_date"],
            time=r["exam_time"],
            classroom=r.get("classroom") or "",
            isCompleted=bool(r.get("is_completed")),
            type=r.get("type") or "экзамен",
            grade=r.get("grade"),
        )
        for r in rows
    ]

def fetch_portfolio() -> list[PortfolioItem] | None:
    rows = _get("tspu_portfolio", order="item_date.desc")
    if rows is None:
        return None
    return [
        PortfolioItem(
            id=str(r["id"]),
            title=r["title"],
            category=r["category"],
            status=r["status"],
            date=datetime.fromisoformat(str(r["item_date"]).replace("Z", "+00:00")),
            source=r.get("source") or "",
        )
        for r in rows
    ]

def _get_where(
    table: str,
    *,
    filters: dict[str, str],
    order: str | None = "updated_at.desc",
    limit: int | None = None,
) -> list[dict[str, Any]] | None:
    if not _enabled():
        return None
    parts = [f"{key}=eq.{value}" for key, value in filters.items()]
    if order:
        parts.append(f"order={order}")
    if limit is not None:
        parts.append(f"limit={limit}")
    url = f"{_base()}/{table}?{'&'.join(parts)}"
    try:
        with httpx.Client(timeout=12.0) as client:
            r = client.get(url, headers=_headers())
            if r.status_code >= 400:
                return None
            data = r.json()
            return data if isinstance(data, list) else None
    except httpx.HTTPError:
        return None


def _insert_row(table: str, row: dict[str, Any]) -> dict[str, Any] | None:
    if not _enabled():
        return None
    url = f"{_base()}/{table}"
    try:
        with httpx.Client(timeout=20.0) as client:
            r = client.post(url, headers=_headers(), json=[row])
            if r.status_code >= 400:
                return None
            data = r.json()
            if isinstance(data, list) and data:
                return data[0]
            return None
    except httpx.HTTPError:
        return None


def _patch_where(table: str, filters: dict[str, str], payload: dict[str, Any]) -> bool:
    if not _enabled():
        return False
    parts = [f"{key}=eq.{value}" for key, value in filters.items()]
    url = f"{_base()}/{table}?{'&'.join(parts)}"
    try:
        with httpx.Client(timeout=20.0) as client:
            r = client.patch(url, headers=_headers(), json=payload)
            return r.status_code < 400
    except httpx.HTTPError:
        return False


def _latest_submissions() -> dict[str, dict[str, Any]]:
    rows = _get("tspu_lab_submissions", order="submitted_at.asc")
    latest: dict[str, dict[str, Any]] = {}
    if not rows:
        return latest
    for row in rows:
        lab_id = str(row.get("lab_id") or "")
        if not lab_id:
            continue
        file_name = str(row.get("file_name") or "").strip()
        if lab_id not in latest:
            latest[lab_id] = dict(row)
            latest[lab_id]["file_name"] = file_name
            continue
        prev = str(latest[lab_id].get("file_name") or "").strip()
        names = [n.strip() for n in prev.split(",") if n.strip()]
        if file_name and file_name not in names:
            names.append(file_name)
        latest[lab_id]["file_name"] = ", ".join(names)
        latest[lab_id]["file_url"] = row.get("file_url") or latest[lab_id].get("file_url")
        latest[lab_id]["submitted_at"] = row.get("submitted_at") or latest[lab_id].get("submitted_at")
    return latest


def _lab_from_row(r: dict[str, Any], submission: dict[str, Any] | None = None) -> LabItem:
    updated = datetime.fromisoformat(str(r["updated_at"]).replace("Z", "+00:00"))
    deadline_raw = r.get("deadline")
    deadline = (
        datetime.fromisoformat(str(deadline_raw).replace("Z", "+00:00"))
        if deadline_raw
        else None
    )
    sub_url = submission.get("file_url") if submission else None
    sub_name = submission.get("file_name") if submission else None
    sub_at_raw = submission.get("submitted_at") if submission else None
    submitted_at = (
        datetime.fromisoformat(str(sub_at_raw).replace("Z", "+00:00"))
        if sub_at_raw
        else None
    )
    return LabItem(
        id=str(r["id"]),
        course=r["course"],
        title=r["title"],
        status=r["status"],
        teacherComment=r.get("teacher_comment"),
        updatedAt=updated,
        deadline=deadline,
        submittedAt=submitted_at,
        workType=r.get("work_type"),
        theme=r.get("theme"),
        score=r.get("score"),
        taskFileUrl=r.get("task_file_url"),
        taskFileName=r.get("task_file_name"),
        submissionFileUrl=sub_url,
        submissionFileName=sub_name,
    )


def fetch_labs() -> list[LabItem] | None:
    rows = _get("tspu_moodle_labs", order="updated_at.desc")
    if rows is None:
        return None
    latest = _latest_submissions()
    return [_lab_from_row(r, latest.get(str(r["id"]))) for r in rows]


def fetch_lab_by_id(lab_id: str) -> LabItem | None:
    rows = _get_where("tspu_moodle_labs", filters={"id": lab_id}, order=None, limit=1)
    if not rows:
        return None
    latest = _latest_submissions().get(lab_id)
    return _lab_from_row(rows[0], latest)


def fetch_lab_comments(lab_id: str) -> list[LabCommentItem] | None:
    rows = _get_where("tspu_lab_comments", filters={"lab_id": lab_id}, order="created_at.asc")
    if rows is None:
        return None
    out: list[LabCommentItem] = []
    for row in rows:
        out.append(
            LabCommentItem(
                id=str(row["id"]),
                text=str(row["text"]),
                timestamp=datetime.fromisoformat(str(row["created_at"]).replace("Z", "+00:00")),
                authorName=str(row.get("author_name") or "Студент"),
            )
        )
    return out


def add_lab_comment(lab_id: str, text: str, author_name: str = "Студент") -> LabCommentItem | None:
    row = _insert_row(
        "tspu_lab_comments",
        {
            "lab_id": lab_id,
            "text": text,
            "author_name": author_name,
        },
    )
    if row is None:
        return None
    return LabCommentItem(
        id=str(row["id"]),
        text=str(row["text"]),
        timestamp=datetime.fromisoformat(str(row["created_at"]).replace("Z", "+00:00")),
        authorName=str(row.get("author_name") or author_name),
    )


def record_lab_submission(lab_id: str, file_name: str, file_url: str | None) -> LabItem | None:
    _insert_row(
        "tspu_lab_submissions",
        {
            "lab_id": lab_id,
            "file_name": file_name,
            "file_url": file_url,
        },
    )
    _patch_where(
        "tspu_moodle_labs",
        {"id": lab_id},
        {
            "status": "На проверке",
            "updated_at": datetime.utcnow().isoformat() + "Z",
        },
    )
    return fetch_lab_by_id(lab_id)


def fetch_app_release() -> dict[str, Any] | None:
    rows = _get("tspu_app_release", order="id.asc")
    if not rows:
        return None
    return rows[0]
