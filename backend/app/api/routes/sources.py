from fastapi import APIRouter
from app.modules.feed.rss_fetcher import RSS_SOURCES
from app.modules.sources.domain_database import domain_db
from urllib.parse import urlparse
import re

router = APIRouter()

# Маппинг RSS доменов на реальные домены для поиска в базе
DOMAIN_OVERRIDE = {
    "feeds.bbci.co.uk": "bbc.com",
    "russian.rt.com": "rt.com",
}

def _extract_domain(url: str) -> str:
    try:
        domain = urlparse(url).netloc.lower()
        return re.sub(r'^www\.', '', domain)
    except:
        return url

@router.get("/sources")
async def get_sources():
    seen_domains = set()
    result = []

    for source in RSS_SOURCES:
        rss_domain = _extract_domain(source["url"])
        lookup_domain = DOMAIN_OVERRIDE.get(rss_domain, rss_domain)

        # Убираем дубли по домену
        if lookup_domain in seen_domains:
            continue
        seen_domains.add(lookup_domain)

        db_data = domain_db.get_trust(lookup_domain)
        trust_score = db_data["trust"]

        result.append({
            "name": source["name"],
            "domain": lookup_domain,
            "url": f"https://{lookup_domain}",
            "rss_url": source["url"],
            "trust_score": trust_score,
            "trust_label": source["trust"],
            "trust_category": db_data["label"],
            "known": db_data["known"],
        })

    result.sort(key=lambda x: x["trust_score"], reverse=True)
    return {"sources": result, "total": len(result)}

from fastapi import Depends, Body, HTTPException
from app.core.database import get_db
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.db_models import UserSource
import uuid as uuid_module

@router.get("/sources/user")
async def get_user_sources(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(UserSource).order_by(UserSource.created_at.desc()))
    sources = result.scalars().all()
    return {"sources": [
        {
            "id": str(s.id),
            "domain": s.domain,
            "name": s.name,
            "rss_url": s.rss_url,
            "trust_score": s.trust_score,
            "enabled": s.enabled,
        }
        for s in sources
    ]}

@router.post("/sources/user")
async def add_user_source(
    name: str = Body(...),
    domain: str = Body(...),
    rss_url: str = Body(None),
    db: AsyncSession = Depends(get_db)
):
    domain = domain.lower().replace("https://", "").replace("http://", "").replace("www.", "").strip("/")
    source = UserSource(domain=domain, name=name, rss_url=rss_url)
    db.add(source)
    await db.commit()
    await db.refresh(source)
    return {"id": str(source.id), "domain": source.domain, "name": source.name, "enabled": source.enabled, "rss_url": source.rss_url, "trust_score": source.trust_score}

@router.patch("/sources/user/{source_id}/toggle")
async def toggle_user_source(source_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(UserSource).where(UserSource.id == uuid_module.UUID(source_id)))
    source = result.scalar_one_or_none()
    if not source:
        raise HTTPException(status_code=404, detail="Источник не найден")
    source.enabled = not source.enabled
    await db.commit()
    return {"id": str(source.id), "enabled": source.enabled}

@router.delete("/sources/user/{source_id}")
async def delete_user_source(source_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(UserSource).where(UserSource.id == uuid_module.UUID(source_id)))
    source = result.scalar_one_or_none()
    if not source:
        raise HTTPException(status_code=404, detail="Источник не найден")
    await db.delete(source)
    await db.commit()
    return {"deleted": True}
