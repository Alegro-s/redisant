import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base

class UserRole(str, enum.Enum):
    super_admin = "super_admin"
    admin = "admin"
    user = "user"
    scammer = "scammer"

class MessageChannel(str, enum.Enum):
    mattermost = "mattermost"
    email = "email"
    telegram = "telegram"

class AlertSeverity(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"
    critical = "critical"

class TrainingLabelType(str, enum.Enum):
    legit = "legit"
    impersonation = "impersonation"
    ai_generated = "ai_generated"
    phishing = "phishing"
    suspicious = "suspicious"
    unknown = "unknown"

class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    display_name: Mapped[str] = mapped_column(String(128), nullable=False)
    email: Mapped[str | None] = mapped_column(String(255), unique=True)
    password_hash: Mapped[str | None] = mapped_column(String(255))
    email_verified: Mapped[bool] = mapped_column(default=False)
    user_settings: Mapped[dict | None] = mapped_column(JSONB, default=dict)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole, name="user_role"), nullable=False)
    mattermost_user_id: Mapped[str | None] = mapped_column(String(64), unique=True)
    telegram_user_id: Mapped[str | None] = mapped_column(String(64), unique=True)
    telegram_chat_id: Mapped[str | None] = mapped_column(String(64), unique=True)
    telegram_notify: Mapped[bool] = mapped_column(default=True)
    is_active: Mapped[bool] = mapped_column(default=True)
    is_blocked: Mapped[bool] = mapped_column(default=False)
    block_reason: Mapped[str | None] = mapped_column(Text)
    blocked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    voice_embedding: Mapped[list | None] = mapped_column(JSONB)
    voice_enrolled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    style_profile: Mapped["StyleProfile | None"] = relationship(back_populates="user", uselist=False)
    ml_profile: Mapped["UserMlProfile | None"] = relationship(back_populates="user", uselist=False)
    messages: Mapped[list["Message"]] = relationship(
        back_populates="sender",
        foreign_keys="Message.sender_id",
    )

class StyleProfile(Base):
    """Linguistic DNA baseline per user."""

    __tablename__ = "style_profiles"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True
    )
    reference_vector: Mapped[dict | None] = mapped_column(JSONB)
    traits: Mapped[dict | None] = mapped_column(JSONB)
    sample_count: Mapped[int] = mapped_column(default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="style_profile")

class UserMlProfile(Base):
    """Агрегат по пользователю для внешнего ИИ: корпус, статистика, состояние модели."""

    __tablename__ = "user_ml_profiles"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True
    )
    message_count_total: Mapped[int] = mapped_column(Integer, default=0)
    message_count_24h: Mapped[int] = mapped_column(Integer, default=0)
    mattermost_count: Mapped[int] = mapped_column(Integer, default=0)
    email_count: Mapped[int] = mapped_column(Integer, default=0)
    avg_risk_score: Mapped[float | None] = mapped_column(Float)
    max_risk_score: Mapped[float | None] = mapped_column(Float)
    avg_message_length: Mapped[float | None] = mapped_column(Float)
    high_risk_count: Mapped[int] = mapped_column(Integer, default=0)
    last_message_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_analyzed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    analysis_status: Mapped[str] = mapped_column(String(32), default="pending")
    needs_reanalysis: Mapped[bool] = mapped_column(Boolean, default=True)
    stylistic_features: Mapped[dict | None] = mapped_column(JSONB)
    model_state: Mapped[dict | None] = mapped_column(JSONB)
    profile_version: Mapped[int] = mapped_column(Integer, default=1)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship(back_populates="ml_profile")

class ChannelKey(Base):
    __tablename__ = "channel_keys"

    channel_id: Mapped[str] = mapped_column(String(128), primary_key=True)
    key_b64: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

class Message(Base):
    __tablename__ = "messages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    sender_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL")
    )
    channel: Mapped[MessageChannel] = mapped_column(Enum(MessageChannel, name="message_channel"), nullable=False)
    external_id: Mapped[str | None] = mapped_column(String(128))
    body: Mapped[str] = mapped_column(Text, nullable=False)
    metadata_: Mapped[dict | None] = mapped_column("metadata", JSONB)
    analysis_status: Mapped[str] = mapped_column(String(32), default="pending")
    analysis_source: Mapped[str] = mapped_column(String(32), default="pending")
    raw_payload: Mapped[dict | None] = mapped_column(JSONB)
    impersonated_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL")
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    sender: Mapped["User | None"] = relationship(back_populates="messages", foreign_keys=[sender_id])
    features: Mapped["MessageFeatures | None"] = relationship(back_populates="message", uselist=False)
    training_label: Mapped["TrainingLabel | None"] = relationship(back_populates="message", uselist=False)
    analysis_runs: Mapped[list["AnalysisRun"]] = relationship(back_populates="message")

class MessageFeatures(Base):
    __tablename__ = "message_features"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    message_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("messages.id", ondelete="CASCADE"), unique=True
    )
    feature_vector: Mapped[dict | None] = mapped_column(JSONB)
    style_similarity: Mapped[float | None] = mapped_column(Float)
    ai_score: Mapped[float | None] = mapped_column(Float)
    metadata_anomaly_score: Mapped[float | None] = mapped_column(Float)
    risk_score: Mapped[float | None] = mapped_column(Float)
    layer_hits: Mapped[dict | None] = mapped_column(JSONB)
    model_name: Mapped[str | None] = mapped_column(String(128))
    model_version: Mapped[str | None] = mapped_column(String(64))
    embedding: Mapped[list | None] = mapped_column(JSONB)
    raw_ai_response: Mapped[dict | None] = mapped_column(JSONB)
    inference_ms: Mapped[int | None] = mapped_column()
    analyzed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    message: Mapped["Message"] = relationship(back_populates="features")

class AnalysisRun(Base):
    __tablename__ = "analysis_runs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    message_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("messages.id", ondelete="CASCADE"), nullable=False
    )
    model_name: Mapped[str] = mapped_column(String(128), nullable=False)
    model_version: Mapped[str | None] = mapped_column(String(64))
    analysis_source: Mapped[str] = mapped_column(String(32), nullable=False)
    request_payload: Mapped[dict | None] = mapped_column(JSONB)
    response_payload: Mapped[dict | None] = mapped_column(JSONB)
    risk_score: Mapped[float | None] = mapped_column(Float)
    inference_ms: Mapped[int | None] = mapped_column()
    success: Mapped[bool] = mapped_column(default=True)
    error_message: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    message: Mapped["Message"] = relationship(back_populates="analysis_runs")

class TrainingLabel(Base):
    """Разметка для обучения — заполняет ИИ-эксперт или автоматически из role=scammer."""

    __tablename__ = "training_labels"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    message_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("messages.id", ondelete="CASCADE"), unique=True
    )
    label: Mapped[TrainingLabelType] = mapped_column(
        Enum(TrainingLabelType, name="training_label_type"), nullable=False
    )
    confidence: Mapped[float | None] = mapped_column(Float)
    labeled_by: Mapped[str] = mapped_column(String(128), default="expert")
    notes: Mapped[str | None] = mapped_column(Text)
    is_gold: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    message: Mapped["Message"] = relationship(back_populates="training_label")

class StyleProfileSnapshot(Base):
    __tablename__ = "style_profile_snapshots"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    reference_vector: Mapped[dict | None] = mapped_column(JSONB)
    traits: Mapped[dict | None] = mapped_column(JSONB)
    sample_count: Mapped[int] = mapped_column(default=0)
    snapshot_reason: Mapped[str] = mapped_column(String(64), default="periodic")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

class DatasetExport(Base):
    __tablename__ = "dataset_exports"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    format: Mapped[str] = mapped_column(String(16), default="jsonl")
    file_path: Mapped[str | None] = mapped_column(String(512))
    record_count: Mapped[int] = mapped_column(default=0)
    filters: Mapped[dict | None] = mapped_column(JSONB)
    created_by: Mapped[str] = mapped_column(String(128), default="system")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

class ChannelLink(Base):
    """Cross-channel linker: MM message <-> email."""

    __tablename__ = "channel_links"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    message_id_a: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("messages.id", ondelete="CASCADE"))
    message_id_b: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("messages.id", ondelete="CASCADE"))
    link_score: Mapped[float] = mapped_column(Float, nullable=False)
    reason_ru: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    action: Mapped[str] = mapped_column(String(64), nullable=False)
    target_username: Mapped[str] = mapped_column(String(64), nullable=False)
    actor_username: Mapped[str] = mapped_column(String(64), default="admin_panel")
    details: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

class Alert(Base):
    __tablename__ = "alerts"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    severity: Mapped[AlertSeverity] = mapped_column(Enum(AlertSeverity, name="alert_severity"), nullable=False)
    alert_type: Mapped[str] = mapped_column(String(64), nullable=False)
    title_ru: Mapped[str] = mapped_column(String(255), nullable=False)
    explanation_ru: Mapped[str] = mapped_column(Text, nullable=False)
    related_message_ids: Mapped[list[uuid.UUID] | None] = mapped_column(ARRAY(UUID(as_uuid=True)))
    target_user_ids: Mapped[list[uuid.UUID] | None] = mapped_column(ARRAY(UUID(as_uuid=True)))
    delivered: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

class ChatReadState(Base):
    __tablename__ = "chat_read_states"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username: Mapped[str] = mapped_column(String(64), nullable=False)
    channel_key: Mapped[str] = mapped_column(String(128), nullable=False)
    last_message_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
    read_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

class ChatPresence(Base):
    __tablename__ = "chat_presence"

    username: Mapped[str] = mapped_column(String(64), primary_key=True)
    last_seen: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    is_online: Mapped[bool] = mapped_column(default=True)

class ShadowMentorCampaign(Base):
    """Бонус: персонализированная симуляция фишинга (Shadow Mentor)."""

    __tablename__ = "shadow_mentor_campaigns"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    target_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    impersonate_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL")
    )
    message_text: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[str] = mapped_column(String(32), default="draft")
    user_response: Mapped[str | None] = mapped_column(Text)
    fell_for_it: Mapped[bool | None] = mapped_column(Boolean)
    detection_score: Mapped[float | None] = mapped_column(Float)
    explanation_ru: Mapped[str | None] = mapped_column(Text)
    traits_used: Mapped[dict | None] = mapped_column(JSONB)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
