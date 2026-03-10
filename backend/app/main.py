from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes.analysis import router as analysis_router
from app.modules.nlp.analyzer import nlp_analyzer
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Загружаем модель при старте — чтобы первый запрос был быстрым
    nlp_analyzer.load()
    yield

app = FastAPI(
    title="FakeScope API",
    description="Детекция фейковых новостей на русском языке",
    version="0.1.0",
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
    return {"status": "ok", "service": "FakeScope API"}
