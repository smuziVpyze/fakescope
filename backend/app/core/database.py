from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.core.config import settings

# Движок — соединение с PostgreSQL
engine = create_async_engine(
    settings.database_url,
    echo=False,  # True если хочешь видеть SQL запросы в логах
)

# Фабрика сессий — через неё делаем запросы к БД
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

# Базовый класс для всех таблиц
class Base(DeclarativeBase):
    pass

# Dependency для FastAPI — даёт сессию на время запроса
async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
