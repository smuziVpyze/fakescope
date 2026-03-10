from fastapi import APIRouter, HTTPException
from app.models.analysis import AnalysisRequest, AnalysisResult, Verdict, ModuleScore
from app.modules.nlp.analyzer import nlp_analyzer

router = APIRouter()

def _verdict(score: float) -> Verdict:
    if score >= 0.65:
        return Verdict.FAKE
    elif score >= 0.35:
        return Verdict.UNVERIFIED
    else:
        return Verdict.TRUE

@router.post("/analyze", response_model=AnalysisResult)
async def analyze(request: AnalysisRequest):
    if not request.url and not request.text:
        raise HTTPException(status_code=400, detail="Нужен url или text")

    text = request.text or request.url

    # NLP анализ
    nlp = nlp_analyzer.analyze(text)

    verdict = _verdict(nlp["fake_score"])

    arguments = [nlp["explanation"]]
    if nlp["clickbait_score"] > 0.3:
        arguments.append(f"Кликбейт-индекс: {nlp['clickbait_score']}")
    if nlp["sentiment"] == "negative":
        arguments.append("Текст написан с целью вызвать негативные эмоции")

    return AnalysisResult(
        verdict=verdict,
        confidence=nlp["fake_score"],
        scores=[
            ModuleScore(
                module="nlp",
                score=nlp["fake_score"],
                explanation=nlp["explanation"]
            )
        ],
        arguments=arguments
    )
