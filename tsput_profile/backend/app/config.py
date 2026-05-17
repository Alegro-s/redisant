from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_name: str = "TSPUT Integration Backend"
    app_env: str = "dev"
    mock_mode: bool = True

    onec_base_url: str = ""
    onec_login: str = ""
    onec_password: str = ""

    moodle_base_url: str = ""
    moodle_token: str = ""

    api_demo_login: str = "student@university.ru"
    api_demo_password: str = "password123"

    moodle_student_id: str = ""
    moodle_email: str = ""
    student_full_name: str = ""
    moodle_password: str = ""

    student_card_id: str = ""
    student_card_full_name: str = ""
    student_card_group: str = ""
    student_card_email: str = ""


settings = Settings()
