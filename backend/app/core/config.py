from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    app_env: str = "development"
    database_url: str = "postgresql+asyncpg://fakescope:fakescope_pass@localhost:5432/fakescope_db"
    redis_url: str = "redis://localhost:6379"
    
    # Разрешаем лишние переменные из .env не ломать приложение
    postgres_user: str = "fakescope"
    postgres_password: str = "fakescope_pass"
    postgres_db: str = "fakescope_db"

    class Config:
        env_file = "../.env"
        extra = "ignore"  # игнорируем неизвестные переменные

settings = Settings()
