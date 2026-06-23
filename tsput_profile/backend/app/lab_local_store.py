from datetime import UTC, datetime, timedelta
from uuid import uuid4

from .schemas import LabCommentItem, LabItem

_local_comments: dict[str, list[LabCommentItem]] = {}
_local_submissions: dict[str, dict[str, str]] = {}


def _default_labs(now: datetime | None = None) -> list[LabItem]:
    now = now or datetime.now(UTC)
    return [
        LabItem(
            id="L1",
            course="Программирование",
            title="ЛР №3",
            status="Принято",
            teacherComment="Хорошая реализация, добавьте тесты.",
            updatedAt=now - timedelta(hours=6),
            deadline=now + timedelta(days=5),
            workType="ЛР",
            theme="Структуры данных",
            score=5,
            taskFileName="LR3_assignment.pdf",
            taskFileUrl="https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
        ),
        LabItem(
            id="L2",
            course="Базы данных",
            title="ЛР №2",
            status="На проверке",
            teacherComment=None,
            updatedAt=now - timedelta(days=1),
            deadline=now + timedelta(days=2),
            workType="ЛР",
            theme="Нормализация",
            score=None,
        ),
        LabItem(
            id="L3",
            course="Веб-программирование",
            title="КР — макет",
            status="Требуются правки",
            teacherComment="Проверьте адаптив и контраст.",
            updatedAt=now - timedelta(hours=20),
            deadline=now - timedelta(days=1),
            workType="КР",
            theme="Вёрстка landing",
            score=2,
        ),
    ]


def merge_local_state(items: list[LabItem]) -> list[LabItem]:
    out: list[LabItem] = []
    for item in items:
        sub = _local_submissions.get(item.id)
        if sub:
            item = item.model_copy(
                update={
                    "status": "На проверке",
                    "submissionFileName": sub.get("file_name"),
                    "submissionFileUrl": sub.get("file_url"),
                }
            )
        out.append(item)
    return out


def get_lab(lab_id: str, base_items: list[LabItem]) -> LabItem | None:
    for item in merge_local_state(base_items):
        if item.id == lab_id:
            return item
    return None


def list_comments(lab_id: str) -> list[LabCommentItem]:
    return list(_local_comments.get(lab_id, []))


def add_comment(lab_id: str, text: str) -> LabCommentItem:
    item = LabCommentItem(
        id=str(uuid4()),
        text=text,
        timestamp=datetime.now(UTC),
        authorName="Студент",
    )
    _local_comments.setdefault(lab_id, []).append(item)
    return item


def record_submission(lab_id: str, file_name: str, file_url: str) -> None:
    _local_submissions[lab_id] = {"file_name": file_name, "file_url": file_url}
