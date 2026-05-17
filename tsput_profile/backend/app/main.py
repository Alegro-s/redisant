from datetime import datetime, time, timedelta, UTC
from fastapi import Body, FastAPI, Header, HTTPException

from .config import settings
from . import local_users_loader
from .schemas import (
    ExamItem,
    GradeItem,
    LabItem,
    LoginRequest,
    LoginResponse,
    PartnerScanBody,
    PartnerServiceItem,
    PortfolioItem,
    ScheduleItem,
    StudentResponse,
)

app = FastAPI(title=settings.app_name)


def _require_auth(authorization: str | None) -> None:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Unauthorized")


def _bearer_token(authorization: str | None) -> str:
    _require_auth(authorization)
    assert authorization is not None
    return authorization.split(" ", 1)[1].strip()


_partner_services_by_token: dict[str, list[PartnerServiceItem]] = {}


@app.get("/health")
def health() -> dict:
    return {"ok": True, "env": settings.app_env, "mock_mode": settings.mock_mode}


@app.post("/api/sync")
def sync() -> dict:
    return {"success": True}


def _normalize_name(value: str) -> str:
    return " ".join(value.strip().split()).casefold()


def _moodle_login_accepted(raw_login: str, password: str) -> bool:
    if not settings.moodle_password:
        return False
    if password != settings.moodle_password:
        return False
    ident = raw_login.strip()
    ident_cf = ident.casefold()
    if settings.moodle_student_id and ident == settings.moodle_student_id.strip():
        return True
    if settings.moodle_email and ident_cf == settings.moodle_email.strip().casefold():
        return True
    if settings.student_full_name and _normalize_name(ident) == _normalize_name(settings.student_full_name):
        return True
    return False


@app.post("/api/auth/login", response_model=LoginResponse)
def login(payload: LoginRequest) -> LoginResponse:
    local_user = local_users_loader.match_local_user(payload.login, payload.password)
    if local_user is not None:
        return LoginResponse(
            success=True,
            token=f"demo_{int(datetime.now(UTC).timestamp())}",
            user=local_user,
        )

    demo_ok = (
        payload.login.strip().casefold() == settings.api_demo_login.strip().casefold()
        and payload.password == settings.api_demo_password
    )
    moodle_ok = _moodle_login_accepted(payload.login, payload.password)

    if demo_ok or moodle_ok:
        user_id = (
            settings.moodle_student_id.strip()
            if moodle_ok and settings.moodle_student_id.strip()
            else "ST001"
        )
        return LoginResponse(
            success=True,
            token=f"demo_{int(datetime.now(UTC).timestamp())}",
            user={
                "id": user_id,
                "name": "Виноградов Игорь Денисович",
                "group": "1521621",
            },
        )
    return LoginResponse(success=False, error="Неверный логин или пароль")


@app.get("/api/student", response_model=StudentResponse)
def student(authorization: str | None = Header(default=None)) -> StudentResponse:
    _require_auth(authorization)
    sid = settings.student_card_id.strip() or "ST001"
    full = settings.student_card_full_name.strip() or "Виноградов Игорь Денисович"
    grp = settings.student_card_group.strip() or "1521621"
    mail = settings.student_card_email.strip() or "lorm2053@gmail.com"
    return StudentResponse(
        id=sid,
        fullName=full,
        group=grp,
        faculty="Институт передовых информационных технологий",
        specialty="Математическое обеспечение и администрирование информационных систем",
        course=4,
        admissionDate=datetime(2022, 9, 1, tzinfo=UTC),
        graduationDate=datetime(2026, 6, 30, tzinfo=UTC),
        email=mail,
        phone="+7 (900) 000-00-00",
        address="г. Тула",
        additionalInfo={
            "recordBook": "22031-15",
            "educationForm": "Очная",
            "city": "Tula",
            "timezone": "Etc/GMT-3",
            "birthDate": "2004-10-21",
            "studentStatus": "Является студентом",
            "trainingLevel": "Бакалавриат",
            "profile": "Информационные системы и базы данных",
            "scholarship": 0,
            "dormitory": "Не указано",
            "averageGrade": 4.7,
            "examsCount": 8,
        },
    )


def _week_slot(weekday: int, hour: int, minute: int, **kwargs) -> ScheduleItem:
    """weekday 0=пн … 6=вс от текущей календарной недели (UTC)."""
    today = datetime.now(UTC).date()
    monday = today - timedelta(days=today.weekday())
    day = monday + timedelta(days=weekday)
    start = datetime.combine(day, time(hour, minute), tzinfo=UTC)
    return ScheduleItem(
        startTime=start,
        endTime=start + timedelta(hours=1, minutes=35),
        **kwargs,
    )


@app.get("/api/schedule", response_model=list[ScheduleItem])
def schedule(authorization: str | None = Header(default=None)) -> list[ScheduleItem]:
    _require_auth(authorization)
    return [
        _week_slot(
            0,
            8,
            40,
            id="S1",
            subject="Большие данные и распределенные системы",
            teacher="Добровольский Николай Николаевич",
            classroom="3-309-3",
            type="лекция",
        ),
        _week_slot(
            0,
            10,
            25,
            id="S2",
            subject="Большие данные и распределенные системы",
            teacher="Добровольский Николай Николаевич",
            classroom="3-308а-3",
            type="лабораторная",
        ),
        _week_slot(
            1,
            8,
            40,
            id="S3",
            subject="Экономико-математические методы и модели",
            teacher="Рарова Елена Михайловна",
            classroom="3-313-3",
            type="лекция",
        ),
        _week_slot(
            3,
            8,
            40,
            id="S4",
            subject="Методы оптимизации",
            teacher="Родионов Александр Валерьевич",
            classroom="3-313-3",
            type="лекция",
        ),
    ]


@app.get("/api/grades", response_model=list[GradeItem])
def grades(authorization: str | None = Header(default=None)) -> list[GradeItem]:
    _require_auth(authorization)
    return [
        GradeItem(
            id="G1",
            subject="Безопасность жизнедеятельности",
            teacher="—",
            value=0,
            type="Зачёт",
            date=datetime(2022, 12, 23, tzinfo=UTC),
            semester=1,
            zet=3,
            hours=108,
            gradeLabel="Зачтено",
        ),
        GradeItem(
            id="G2",
            subject="Введение в программирование",
            teacher="—",
            value=4,
            type="Экзамен",
            date=datetime(2023, 1, 17, tzinfo=UTC),
            semester=1,
            zet=5,
            hours=180,
            gradeLabel="Хорошо",
        ),
        GradeItem(
            id="G3",
            subject="Дискретная математика",
            teacher="—",
            value=0,
            type="Зачёт",
            date=datetime(2022, 12, 28, tzinfo=UTC),
            semester=1,
            zet=4,
            hours=144,
            gradeLabel="Зачтено",
        ),
        GradeItem(
            id="G4",
            subject="Математический анализ",
            teacher="—",
            value=4,
            type="Экзамен",
            date=datetime(2023, 1, 12, tzinfo=UTC),
            semester=1,
            zet=5,
            hours=180,
            gradeLabel="Хорошо",
        ),
        GradeItem(
            id="G5",
            subject="Алгоритмы",
            teacher="Петров А.А.",
            value=5,
            type="лабораторная",
            date=datetime.now(UTC) - timedelta(days=5),
            semester=7,
            zet=3,
            hours=36,
        ),
    ]


@app.get("/api/exams", response_model=list[ExamItem])
def exams(authorization: str | None = Header(default=None)) -> list[ExamItem]:
    _require_auth(authorization)
    return [
        ExamItem(
            id="E1",
            subject="Компьютерные сети",
            teacher="Иванова Н.В.",
            date="20.04.2026",
            time="10:00",
            classroom="ауд. 102",
            isCompleted=False,
            type="экзамен",
        )
    ]


@app.get("/api/portfolio", response_model=list[PortfolioItem])
def portfolio(authorization: str | None = Header(default=None)) -> list[PortfolioItem]:
    _require_auth(authorization)
    return [
        PortfolioItem(
            id="P1",
            title="Методы оптимизации 2025 - 2026",
            category="Учебная дисциплина",
            status="Подтверждено",
            date=datetime.now(UTC) - timedelta(days=120),
            source="1C/Учебный план",
        ),
        PortfolioItem(
            id="P2",
            title="Большие данные и распределенные системы 2025 - 2026",
            category="Учебная дисциплина",
            status="Подтверждено",
            date=datetime.now(UTC) - timedelta(days=110),
            source="1C/Учебный план",
        ),
        PortfolioItem(
            id="P3",
            title="Производственная преддипломная практика 2025 - 2026",
            category="Практика",
            status="В процессе",
            date=datetime.now(UTC) - timedelta(days=90),
            source="1C/Практика",
        ),
        PortfolioItem(
            id="P4",
            title="Экономико-математические методы и модели 2025 - 2026",
            category="Учебная дисциплина",
            status="Подтверждено",
            date=datetime.now(UTC) - timedelta(days=80),
            source="1C/Учебный план",
        ),
        PortfolioItem(
            id="P5",
            title="Подготовка к процедуре защиты ВКР 2025 - 2026",
            category="ВКР",
            status="В процессе",
            date=datetime.now(UTC) - timedelta(days=60),
            source="1C/ВКР",
        ),
        PortfolioItem(
            id="P6",
            title="Компьютерное моделирование 2025 - 2026",
            category="Учебная дисциплина",
            status="Подтверждено",
            date=datetime.now(UTC) - timedelta(days=50),
            source="1C/Учебный план",
        ),
        PortfolioItem(
            id="P7",
            title="Рекурсивно-логическое программирование 2025 - 2026",
            category="Учебная дисциплина",
            status="Подтверждено",
            date=datetime.now(UTC) - timedelta(days=40),
            source="1C/Учебный план",
        ),
    ]


@app.post("/api/partner-services/scan")
def partner_scan(
    authorization: str | None = Header(default=None),
    body: PartnerScanBody = Body(...),
) -> dict:
    tok = _bearer_token(authorization)
    raw = body.raw.strip()
    if not raw:
        raise HTTPException(status_code=400, detail="empty raw")
    item = PartnerServiceItem(
        id=f"ps_{abs(hash(raw)) % 10 ** 10}",
        title="Услуга по QR",
        partnerName="Партнёр (интеграция)",
        description=raw if len(raw) <= 500 else raw[:497] + "...",
        validUntil=None,
    )
    _partner_services_by_token.setdefault(tok, []).append(item)
    return {"ok": True}


@app.get("/api/partner-services", response_model=list[PartnerServiceItem])
def partner_services_list(authorization: str | None = Header(default=None)) -> list[PartnerServiceItem]:
    tok = _bearer_token(authorization)
    return list(_partner_services_by_token.get(tok, []))


@app.get("/api/moodle/labs", response_model=list[LabItem])
def moodle_labs(authorization: str | None = Header(default=None)) -> list[LabItem]:
    _require_auth(authorization)
    now = datetime.now(UTC)
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
