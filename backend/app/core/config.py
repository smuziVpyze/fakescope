from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    app_env: str = "development"
    database_url: str = "postgresql+asyncpg://fakescope:fakescope_pass@localhost:5432/fakescope_db"
    redis_url: str = "redis://localhost:6379"
    postgres_user: str = "fakescope"
    postgres_password: str = "fakescope_pass"
    postgres_db: str = "fakescope_db"
    google_factcheck_api_key: str = ""

    class Config:
        env_file = "../.env"
        extra = "ignore"

settings = Settings()
