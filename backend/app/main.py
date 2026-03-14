from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.api.routes.analysis import router as analysis_router
from app.modules.nlp.analyzer import nlp_analyzer
from app.core.database import engine, Base

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Создаём таблицы если их нет
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("✅ База данных готова")

    # Загружаем RuBERT
    nlp_analyzer.load()
    yield

    await engine.dispose()

app = FastAPI(
    title="FakeScope API",
    description="Детекция фейковых новостей на русском языке",
    version="0.2.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(analysis_router, prefix="/api")

@app.get("/")
async def root():
    return {"status": "ok", "service": "FakeScope API", "version": "0.2.0"}
