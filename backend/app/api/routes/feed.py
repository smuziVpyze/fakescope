from fastapi import APIRouter, Query
from app.services.feed_service import feed_service

router = APIRouter()

@router.get("/feed")
async def get_feed(refresh: bool = Query(False)):
    articles = await feed_service.get_feed_async(force_refresh=refresh)
    return {"articles": articles, "total": len(articles)}

@router.post("/feed/refresh")
async def refresh_feed():
    articles = await feed_service.get_feed_async(force_refresh=True)
    return {"status": "refreshed", "total": len(articles)}
