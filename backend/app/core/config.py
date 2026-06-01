import os
from pydantic_settings import BaseSettings

_ENV_FILE = os.path.join(
    os.path.dirname(
        os.path.dirname(
            os.path.dirname(
                os.path.abspath(__file__)
            )
        )
    ),
    ".env"
)

class Settings(BaseSettings):
    app_env: str = "development"
    database_url: str = "postgresql+asyncpg://fakescope:fakescope_pass@localhost:5432/fakescope_db"
    redis_url: str = "redis://localhost:6379"
    postgres_user: str = "fakescope"
    postgres_password: str = "fakescope_pass"
    postgres_db: str = "fakescope_db"
    google_factcheck_api_key: str = ""
    news_api_key: str = ""

    class Config:
        env_file = _ENV_FILE
        extra = "ignore"

settings = Settings()
