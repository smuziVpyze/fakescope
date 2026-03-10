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
    score: float        # 0.0 - 1.0, где 1.0 = точно фейк
    explanation: str

class AnalysisResult(BaseModel):
    verdict: Verdict
    confidence: float
    scores: list[ModuleScore]
    arguments: list[str]
