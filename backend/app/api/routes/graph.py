from fastapi import APIRouter
from app.modules.network.spread_analyzer import spread_analyzer

router = APIRouter()

@router.get("/graph")
async def get_graph(url: str, title: str):
    """Граф распространения новости"""
    result = spread_analyzer.analyze(url=url, title=title)
    return result
