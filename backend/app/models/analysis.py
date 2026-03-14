from pydantic import BaseModel
from enum import Enum
from typing import Optional

class Verdict(str, Enum):
    FAKE = "fake"
    TRUE = "true"
    UNVERIFIED = "unverified"

class AnalysisRequest(BaseModel):
    url: Optional[str] = None
    text: Optional[str] = None

class ModuleScore(BaseModel):
    module: str
    score: float
    explanation: str

class DomainInfo(BaseModel):
    domain: str
    trust_score: float
    explanation: str

class AnalysisResult(BaseModel):
    verdict: Verdict
    confidence: float
    scores: list[ModuleScore]
    arguments: list[str]
    domain_info: Optional[DomainInfo] = None
