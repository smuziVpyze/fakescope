from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from app.models.analysis import AnalysisRequest, AnalysisResult, Verdict, ModuleScore, DomainInfo, WordHighlight
from app.models.db_models import AnalysisRecord
from app.modules.nlp.analyzer import nlp_analyzer
from app.modules.nlp.topic_classifier import topic_classifier
from app.modules.sources.domain_analyzer import domain_analyzer
from app.modules.factcheck.checker import factchecker
from app.modules.factcheck.google_factcheck import google_factchecker
from app.core.database import get_db

router = APIRouter()

def _verdict(score: float) -> Verdict:
    if score >= 0.65:
        return Verdict.FAKE
    elif score >= 0.35:
        return Verdict.UNVERIFIED
    else:
        return Verdict.TRUE

def _fusion(nlp_score: float, domain_score: float, fact_score: float,
            has_url: bool, fact_found: bool, google_found: bool) -> float:
    """
    Fusion aggregator с правильными весами.
    Если фактчек не нашёл данных — он вообще не участвует в формуле.
    """
    if has_url:
        if fact_found and google_found:
            # Google нашёл — доверяем фактчеку больше всего
            return round(nlp_score * 0.20 + domain_score * 0.20 + fact_score * 0.60, 3)
        elif fact_found:
            # Только локальный фактчек или Google без уверенности
            return round(nlp_score * 0.35 + domain_score * 0.25 + fact_score * 0.40, 3)
        else:
            # Нет данных фактчека — только NLP + домен
            return round(nlp_score * 0.60 + domain_score * 0.40, 3)
    else:
        if fact_found and google_found:
            return round(nlp_score * 0.25 + fact_score * 0.75, 3)
        elif fact_found:
            return round(nlp_score * 0.50 + fact_score * 0.50, 3)
        else:
            # Нет данных фактчека — только NLP
            return round(nlp_score * 1.0, 3)

@router.post("/analyze", response_model=AnalysisResult)
async def analyze(request: AnalysisRequest, db: AsyncSession = Depends(get_db)):
    if not request.url and not request.text:
        raise HTTPException(status_code=400, detail="Нужен url или text")

    text = request.text or request.title or request.url

    # Для фактчека — пробуем получить заголовок страницы если есть URL
    factcheck_query = request.text or ""
    if request.url and not request.text:
        try:
            import requests as req
            from bs4 import BeautifulSoup
            resp = req.get(request.url, timeout=5, headers={"User-Agent": "Mozilla/5.0"})
            soup = BeautifulSoup(resp.text, "html.parser")
            og_title = soup.find("meta", property="og:title")
            title = soup.find("title")
            if og_title:
                factcheck_query = og_title.get("content", "")
            elif title:
                factcheck_query = title.get_text(strip=True)
            else:
                factcheck_query = request.title or ""
        except:
            factcheck_query = request.title or ""

    # Модуль 1 — NLP
    nlp = nlp_analyzer.analyze(text)

    # Модуль 2 — Домен
    domain_data = None
    domain_score = 0.0
    if request.url:
        domain_data = domain_analyzer.analyze(request.url)
        domain_score = domain_data["trust_score"]

    # Модуль 3 — Локальный фактчек (FAISS)
    local_fact = factchecker.check(factcheck_query)

    # Модуль 4 — Google Fact Check
    google_fact = google_factchecker.check(factcheck_query)

    # Определяем наличие данных фактчека
    google_found = google_fact["found"]
    local_found = local_fact["found"]
    fact_found = google_found or local_found

    # Итоговый fact_score
    if google_found and local_found:
        fact_score = google_fact["score"] * 0.6 + local_fact["score"] * 0.4
        fact_explanation = google_fact["explanation"]
    elif google_found:
        fact_score = google_fact["score"]
        fact_explanation = google_fact["explanation"]
    elif local_found:
        fact_score = local_fact["score"]
        fact_explanation = local_fact["explanation"]
    else:
        fact_score = None
        fact_explanation = None

    # Fusion
    final_score = _fusion(
        nlp_score=nlp["fake_score"],
        domain_score=domain_score,
        fact_score=fact_score if fact_score is not None else 0.0,
        has_url=bool(request.url),
        fact_found=fact_found,
        google_found=google_found,
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
    if fact_explanation:
        arguments.append(f"Фактчек: {fact_explanation}")
    else:
        arguments.append("Фактчек: совпадений в базе не найдено")

    # Скоры для UI
    scores = [
        ModuleScore(module="nlp", score=nlp["fake_score"], explanation=nlp["explanation"])
    ]
    if domain_data:
        scores.append(ModuleScore(
            module="domain",
            score=domain_score,
            explanation=domain_data["explanation"]
        ))
    if google_found:
        scores.append(ModuleScore(
            module="google_factcheck",
            score=google_fact["score"],
            explanation=google_fact["explanation"]
        ))
    elif local_found:
        scores.append(ModuleScore(
            module="factcheck",
            score=local_fact["score"],
            explanation=local_fact["explanation"]
        ))

    domain_info = DomainInfo(
        domain=domain_data["domain"],
        trust_score=domain_data["trust_score"],
        explanation=domain_data["explanation"]
    ) if domain_data else None

    record = AnalysisRecord(
        input_text=request.text or request.title,
        input_url=request.url,
        verdict=verdict.value,
        confidence=final_score,
        arguments=arguments,
        scores=[s.model_dump() for s in scores],
    )
    db.add(record)
    await db.commit()

    # XAI
    word_highlights = [
        WordHighlight(word=w["word"], weight=w["weight"])
        for w in nlp_analyzer.explain(text)
    ]

    # Тематика
    topic = topic_classifier.classify(factcheck_query or text)

    return AnalysisResult(
        verdict=verdict,
        confidence=final_score,
        scores=scores,
        arguments=arguments,
        domain_info=domain_info,
        category=topic["category"],
        category_ru=topic["category_ru"],
        category_emoji=topic["category_emoji"],
        word_highlights=word_highlights,
        title=factcheck_query if factcheck_query != (request.url or "") else (request.title or ""),
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
    background_tasks.add_task(factchecker.scrape_medialeaks, 3)
    return {"status": "started", "message": "Парсинг запущен в фоне"}

@router.get("/factcheck/stats")
async def factcheck_stats():
    return {
        "total_facts": len(factchecker.facts),
        "loaded": factchecker.loaded,
        "google_factcheck": google_factchecker.loaded,
    }
