from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from app.models.analysis import AnalysisRequest, AnalysisResult, Verdict, ModuleScore, DomainInfo
from app.models.db_models import AnalysisRecord
from app.modules.nlp.analyzer import nlp_analyzer
from app.modules.sources.domain_analyzer import domain_analyzer
from app.modules.factcheck.checker import factchecker
from app.core.database import get_db

router = APIRouter()

def _verdict(score: float) -> Verdict:
    if score >= 0.65:
        return Verdict.FAKE
    elif score >= 0.35:
        return Verdict.UNVERIFIED
    else:
        return Verdict.TRUE

@router.post("/analyze", response_model=AnalysisResult)
async def analyze(request: AnalysisRequest, db: AsyncSession = Depends(get_db)):
    if not request.url and not request.text:
        raise HTTPException(status_code=400, detail="Нужен url или text")

    text = request.text or request.url

    # Модуль 1 — NLP
    nlp = nlp_analyzer.analyze(text)

    # Модуль 2 — Домен
    domain_data = None
    domain_score = 0.0
    if request.url:
        domain_data = domain_analyzer.analyze(request.url)
        domain_score = domain_data["trust_score"]

    # Модуль 3 — Фактчек
    fact = factchecker.check(text)
    fact_score = fact["score"]

    # Fusion — взвешенное объединение
    if request.url:
        final_score = round(
            nlp["fake_score"] * 0.4 +
            domain_score    * 0.3 +
            fact_score      * 0.3,
            3
        )
    else:
        final_score = round(
            nlp["fake_score"] * 0.6 +
            fact_score        * 0.4,
            3
        )

    verdict = _verdict(final_score)

    # Аргументы
    arguments = [nlp["explanation"]]
    if nlp["clickbait_score"] > 0.3:
        arguments.append(f"Кликбейт-индекс: {nlp['clickbait_score']}")
    if nlp["sentiment"] == "negative":
        arguments.append("Текст написан с целью вызвать негативные эмоции")
    if domain_data:
        arguments.append(f"Источник: {domain_data['explanation']}")
    if fact["found"]:
        arguments.append(f"Фактчек: {fact['explanation']}")

    # Скоры модулей
    scores = [
        ModuleScore(module="nlp", score=nlp["fake_score"], explanation=nlp["explanation"])
    ]
    if domain_data:
        scores.append(ModuleScore(module="domain", score=domain_score, explanation=domain_data["explanation"]))
    if fact["found"]:
        scores.append(ModuleScore(module="factcheck", score=fact_score, explanation=fact["explanation"]))

    domain_info = DomainInfo(
        domain=domain_data["domain"],
        trust_score=domain_data["trust_score"],
        explanation=domain_data["explanation"]
    ) if domain_data else None

    # Сохраняем в БД
    record = AnalysisRecord(
        input_text=request.text,
        input_url=request.url,
        verdict=verdict.value,
        confidence=final_score,
        arguments=arguments,
        scores=[s.model_dump() for s in scores],
    )
    db.add(record)
    await db.commit()

    return AnalysisResult(
        verdict=verdict,
        confidence=final_score,
        scores=scores,
        arguments=arguments,
        domain_info=domain_info,
    )

@router.get("/history")
async def history(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(AnalysisRecord).order_by(desc(AnalysisRecord.created_at)).limit(20)
    )
    records = result.scalars().all()
    return [
        {
            "id": str(r.id),
            "verdict": r.verdict,
            "confidence": r.confidence,
            "text": r.input_text[:100] + "..." if r.input_text and len(r.input_text) > 100 else r.input_text,
            "url": r.input_url,
            "arguments": r.arguments,
            "created_at": r.created_at.isoformat(),
        }
        for r in records
    ]

@router.post("/factcheck/scrape")
async def scrape_factcheck(background_tasks: BackgroundTasks):
    """Запускает парсинг Medialeaks в фоне"""
    background_tasks.add_task(factchecker.scrape_medialeaks, 3)
    return {"status": "started", "message": "Парсинг запущен в фоне"}

@router.get("/factcheck/stats")
async def factcheck_stats():
    """Статистика фактчек базы"""
    return {
        "total_facts": len(factchecker.facts),
        "loaded": factchecker.loaded,
    }
