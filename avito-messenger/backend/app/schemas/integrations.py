from pydantic import BaseModel, Field

class EmailWebhookIn(BaseModel):
    """Демо/интеграция входящего письма (без реального SMTP на хакатоне)."""

    from_email: str = Field(..., description="Адрес отправителя")
    from_name: str | None = None
    to_email: str | None = None
    subject: str | None = None
    body: str
    username: str | None = Field(None, description="Реальный отправитель в нашей БД (scammer1)")
    impersonates_username: str | None = Field("ceo", description="Под кого выдаёт себя")
    secret: str | None = None

class TelegramWebhookIn(BaseModel):
    """Упрощённый webhook (демо) или прокси от Telegram Bot API."""

    text: str
    username: str | None = Field(None, description="Логин в AI Shield")
    telegram_user_id: str | None = None
    chat_id: str | None = None
    impersonates_username: str | None = None
    secret: str | None = None

    update: dict | None = None
