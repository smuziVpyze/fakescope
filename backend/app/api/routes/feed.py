from fastapi import APIRouter, Query
from app.services.feed_service import feed_service

router = APIRouter()

@router.get("/feed")
async def get_feed(refresh: bool = Query(False)):
    """Возвращает ленту новостей с анализом"""
    articles = feed_service.get_feed(force_refresh=refresh)
    return {"articles": articles, "total": len(articles)}

@router.post("/feed/refresh")
async def refresh_feed():
    """Принудительно обновляет ленту"""
    articles = feed_service.get_feed(force_refresh=True)
    return {"status": "refreshed", "total": len(articles)}
