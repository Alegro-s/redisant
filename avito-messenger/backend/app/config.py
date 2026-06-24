from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    postgres_host: str = "localhost"
    postgres_port: int = 5433
    postgres_user: str = "aishield"
    postgres_password: str = "aishield_dev"
    postgres_db: str = "aishield"

    api_host: str = "0.0.0.0"
    api_port: int = 8000
    debug: bool = True

    mattermost_url: str = "http://localhost:8065"
    mattermost_webhook_secret: str = ""
    mattermost_bot_token: str = ""
    mattermost_alert_channel_id: str = ""
    mattermost_dm_alerts: bool = True

    telegram_bot_token: str = ""
    telegram_alert_chat_id: str = ""
    telegram_alerts_enabled: bool = True
    telegram_webhook_secret: str = ""
    telegram_webhook_public_url: str = ""
    telegram_relay_url: str = ""
    telegram_relay_secret: str = ""
    email_webhook_secret: str = ""
    fcm_server_key: str = ""
    fcm_project_id: str = ""
    fcm_service_account_file: str = ""

    ai_service_url: str = ""
    ai_service_timeout: int = 30

    secure_config_seed: str = ""
    inference_profile: str = ""

    lm_studio_url: str = ""
    lm_studio_model: str = ""
    lm_studio_api_token: str = ""
    lm_studio_timeout: int = 45
    lm_studio_min_risk: float = 0.4

    admin_api_key: str = ""
    cors_origins: str = ""

    whisper_url: str = ""
    whisper_api_token: str = ""
    whisper_timeout: int = 60

    voice_analyze_url: str = ""
    voice_analyze_token: str = ""
    voice_analyze_timeout: int = 45

    ai_core_url: str = ""
    ai_core_timeout: int = 30

    risk_alert_threshold: float = 0.42
    risk_critical_threshold: float = 0.75
    risk_high_threshold: float = 0.55
    alert_cooldown_sec: int = 300

    public_host: str = ""

    smtp_host: str = ""
    smtp_port: int = 465
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = ""
    smtp_use_ssl: bool = True
    app_display_name: str = "YALGSI"

    auth_rate_limit_login: int = 12
    auth_rate_limit_register: int = 6
    auth_rate_limit_window_sec: int = 60

    msg_analysis_key: str = ""
    msg_admin_view_key: str = ""

    @property
    def database_url(self) -> str:
        return (
            f"postgresql+psycopg2://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

@lru_cache
def get_settings() -> Settings:
    return Settings()
