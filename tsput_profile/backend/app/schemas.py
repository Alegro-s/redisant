from datetime import datetime
from pydantic import BaseModel


class LoginRequest(BaseModel):
    login: str
    password: str


class LoginResponse(BaseModel):
    success: bool
    token: str | None = None
    error: str | None = None
    user: dict | None = None


class StudentResponse(BaseModel):
    id: str
    fullName: str
    group: str
    faculty: str
    specialty: str
    course: int
    admissionDate: datetime
    graduationDate: datetime
    email: str
    phone: str
    address: str
    additionalInfo: dict


class ScheduleItem(BaseModel):
    id: str
    subject: str
    teacher: str
    classroom: str
    startTime: datetime
    endTime: datetime
    type: str


class GradeItem(BaseModel):
    id: str
    subject: str
    teacher: str
    value: int
    type: str
    date: datetime
    semester: int | None = None
    zet: int | None = None
    hours: int | None = None
    gradeLabel: str | None = None


class ExamItem(BaseModel):
    id: str
    subject: str
    teacher: str
    date: str
    time: str
    classroom: str
    isCompleted: bool
    type: str
    grade: int | None = None


class PortfolioItem(BaseModel):
    id: str
    title: str
    category: str
    status: str
    date: datetime
    source: str


class LabItem(BaseModel):
    id: str
    course: str
    title: str
    status: str
    teacherComment: str | None = None
    updatedAt: datetime
    deadline: datetime | None = None
    workType: str | None = None
    theme: str | None = None
    score: int | None = None


class PartnerScanBody(BaseModel):
    raw: str


class PartnerServiceItem(BaseModel):
    id: str
    title: str
    partnerName: str
    description: str
    validUntil: datetime | None = None
