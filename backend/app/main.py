from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.api.routes.analysis import router as analysis_router
from app.api.routes.feed import router as feed_router
from app.api.routes.graph import router as graph_router
from app.modules.nlp.analyzer import nlp_analyzer
from app.modules.factcheck.checker import factchecker
from app.modules.factcheck.google_factcheck import google_factchecker
from app.modules.sources.domain_database import domain_db
from app.modules.nlp.topic_classifier import topic_classifier
from app.core.database import engine, Base

@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("✅ База данных готова")
    nlp_analyzer.load()
    factchecker.load()
    google_factchecker.load()
    domain_db.load()
    topic_classifier.load()
    yield
    await engine.dispose()

app = FastAPI(
    title="FakeScope API",
    description="Детекция фейковых новостей на русском языке",
    version="0.6.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(analysis_router, prefix="/api")
app.include_router(feed_router, prefix="/api")
app.include_router(graph_router, prefix="/api")

@app.get("/")
async def root():
    return {"status": "ok", "service": "FakeScope API", "version": "0.6.0"}

@app.get("/api/domains/stats")
async def domain_stats():
    return {"total_domains": domain_db.total}
