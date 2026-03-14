from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from app.models.analysis import AnalysisRequest, AnalysisResult, Verdict, ModuleScore
from app.models.db_models import AnalysisRecord
from app.modules.nlp.analyzer import nlp_analyzer
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
    nlp = nlp_analyzer.analyze(text)
    verdict = _verdict(nlp["fake_score"])

    arguments = [nlp["explanation"]]
    if nlp["clickbait_score"] > 0.3:
        arguments.append(f"Кликбейт-индекс: {nlp['clickbait_score']}")
    if nlp["sentiment"] == "negative":
        arguments.append("Текст написан с целью вызвать негативные эмоции")

    scores = [ModuleScore(module="nlp", score=nlp["fake_score"], explanation=nlp["explanation"])]

    # Сохраняем в PostgreSQL
    record = AnalysisRecord(
        input_text=request.text,
        input_url=request.url,
        verdict=verdict.value,
        confidence=nlp["fake_score"],
        arguments=arguments,
        scores=[s.model_dump() for s in scores],
    )
    db.add(record)
    await db.commit()

    return AnalysisResult(verdict=verdict, confidence=nlp["fake_score"], scores=scores, arguments=arguments)

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
