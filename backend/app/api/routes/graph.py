from fastapi import APIRouter, Query
from typing import Optional
from app.modules.network.spread_analyzer import spread_analyzer

router = APIRouter()

@router.get("/graph")
async def get_graph(title: str, url: Optional[str] = None):
    """Граф распространения — работает и с URL и с текстом"""
    result = spread_analyzer.analyze(title=title, url=url)
    return result
