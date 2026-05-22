from pydantic import BaseModel
from enum import Enum
from typing import Optional, List

class Verdict(str, Enum):
    FAKE = "fake"
    TRUE = "true"
    UNVERIFIED = "unverified"

class AnalysisRequest(BaseModel):
    url: Optional[str] = None
    text: Optional[str] = None
    title: Optional[str] = None  # заголовок из ленты — fallback для NLP если URL не парсится

class ModuleScore(BaseModel):
    module: str
    score: float
    explanation: str

class DomainInfo(BaseModel):
    domain: str
    trust_score: float
    explanation: str

class WordHighlight(BaseModel):
    word: str
    weight: float

class AnalysisResult(BaseModel):
    verdict: Verdict
    confidence: float
    scores: List[ModuleScore]
    arguments: List[str]
    domain_info: Optional[DomainInfo] = None
    category: Optional[str] = None
    category_ru: Optional[str] = None
    category_emoji: Optional[str] = None
    word_highlights: Optional[List[WordHighlight]] = None
