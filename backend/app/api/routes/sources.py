from fastapi import APIRouter, Depends, Body, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from urllib.parse import urlparse
import re
import uuid as uuid_module
import redis as redis_lib

from app.modules.sources.domain_database import domain_db
from app.core.database import get_db
from app.models.db_models import UserSource, BuiltinSource
from app.core.config import settings

router = APIRouter()

def _normalize_domain(raw: str) -> str:
    d = raw.lower()
    d = d.replace("https://", "").replace("http://", "")
    d = re.sub(r'^www\.', '', d)
    d = d.strip("/").split("/")[0]
    return d

def _invalidate_feed_cache():
    try:
        r = redis_lib.from_url(settings.redis_url)
        r.delete("fakescope:feed:latest")
        print("🗑️ Кэш ленты сброшен")
    except Exception as e:
        print(f"⚠️ Не удалось сбросить кэш: {e}")


# ── Встроенные источники ────────────────────────────────────────────────────

@router.get("/sources")
async def get_sources(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(BuiltinSource))
    sources = result.scalars().all()

    out = []
    for s in sources:
        db_data = domain_db.get_trust(s.domain)
        base_trust = db_data["trust"]
        user_trust = s.user_trust_score
        effective_trust = user_trust if user_trust is not None else base_trust
        out.append({
            "id": str(s.id),
            "name": s.name,
            "domain": s.domain,
            "url": f"https://{s.domain}",
            "rss_url": s.rss_url,
            "base_trust_score": round(base_trust, 3),
            "user_trust_score": round(user_trust, 3) if user_trust is not None else None,
            "effective_trust_score": round(effective_trust, 3),
            "trust_category": db_data["label"],
            "known": db_data["known"],
            "enabled": s.enabled,
            "is_builtin": True,
        })

    out.sort(key=lambda x: x["effective_trust_score"], reverse=True)
    return {"sources": out, "total": len(out)}


@router.patch("/sources/builtin/{domain}/toggle")
async def toggle_builtin_source(domain: str, db: AsyncSession = Depends(get_db)):
    domain = _normalize_domain(domain)
    result = await db.execute(select(BuiltinSource).where(BuiltinSource.domain == domain))
    source = result.scalar_one_or_none()
    if source is None:
        raise HTTPException(status_code=404, detail="Встроенный источник не найден")

    source.enabled = not source.enabled
    await db.commit()
    await db.refresh(source)
    _invalidate_feed_cache()
    return {"domain": source.domain, "enabled": source.enabled}


@router.patch("/sources/builtin/{domain}/trust")
async def set_builtin_trust(
    domain: str,
    trust_score: float = Body(..., ge=0.0, le=1.0, embed=True),
    db: AsyncSession = Depends(get_db),
):
    domain = _normalize_domain(domain)
    result = await db.execute(select(BuiltinSource).where(BuiltinSource.domain == domain))
    source = result.scalar_one_or_none()
    if source is None:
        raise HTTPException(status_code=404, detail="Встроенный источник не найден")

    source.user_trust_score = trust_score
    await db.commit()
    await db.refresh(source)
    db_data = domain_db.get_trust(domain)
    return {
        "domain": source.domain,
        "base_trust_score": db_data["trust"],
        "user_trust_score": source.user_trust_score,
    }


@router.delete("/sources/builtin/{domain}/trust")
async def reset_builtin_trust(domain: str, db: AsyncSession = Depends(get_db)):
    domain = _normalize_domain(domain)
    result = await db.execute(select(BuiltinSource).where(BuiltinSource.domain == domain))
    source = result.scalar_one_or_none()
    if source:
        source.user_trust_score = None
        await db.commit()
    db_data = domain_db.get_trust(domain)
    return {"domain": domain, "base_trust_score": db_data["trust"], "user_trust_score": None}


# ── Пользовательские источники ──────────────────────────────────────────────

@router.get("/sources/user")
async def get_user_sources(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(UserSource)
        .where(UserSource.is_builtin == False)
        .order_by(UserSource.created_at.desc())
    )
    sources = result.scalars().all()
    return {"sources": [
        {
            "id": str(s.id),
            "domain": s.domain,
            "name": s.name,
            "rss_url": s.rss_url,
            "base_trust_score": round(s.trust_score, 3),
            "user_trust_score": round(s.user_trust_score, 3) if s.user_trust_score is not None else None,
            "effective_trust_score": round(
                s.user_trust_score if s.user_trust_score is not None else s.trust_score, 3
            ),
            "enabled": s.enabled,
        }
        for s in sources
    ]}


@router.post("/sources/user")
async def add_user_source(
    name: str = Body(...),
    domain: str = Body(...),
    rss_url: str = Body(None),
    db: AsyncSession = Depends(get_db),
):
    domain = _normalize_domain(domain)

    existing = await db.execute(select(UserSource).where(UserSource.domain == domain))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail=f"Источник '{domain}' уже добавлен")

    db_data = domain_db.get_trust(domain)
    base_trust = db_data["trust"] if db_data["known"] else 0.5

    source = UserSource(
        domain=domain,
        name=name,
        rss_url=rss_url if rss_url and rss_url.strip() else None,
        trust_score=base_trust,
        user_trust_score=None,
        is_builtin=False,
        enabled=True,
    )
    db.add(source)
    await db.commit()
    await db.refresh(source)
    _invalidate_feed_cache()

    return {
        "id": str(source.id),
        "domain": source.domain,
        "name": source.name,
        "rss_url": source.rss_url,
        "base_trust_score": round(source.trust_score, 3),
        "user_trust_score": None,
        "effective_trust_score": round(source.trust_score, 3),
        "enabled": source.enabled,
    }


@router.patch("/sources/user/{source_id}/toggle")
async def toggle_user_source(source_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(UserSource).where(
            UserSource.id == uuid_module.UUID(source_id),
            UserSource.is_builtin == False,
        )
    )
    source = result.scalar_one_or_none()
    if not source:
        raise HTTPException(status_code=404, detail="Источник не найден")
    source.enabled = not source.enabled
    await db.commit()
    _invalidate_feed_cache()
    return {"id": str(source.id), "enabled": source.enabled}


@router.patch("/sources/user/{source_id}/trust")
async def set_user_trust(
    source_id: str,
    trust_score: float = Body(..., ge=0.0, le=1.0, embed=True),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(UserSource).where(
            UserSource.id == uuid_module.UUID(source_id),
            UserSource.is_builtin == False,
        )
    )
    source = result.scalar_one_or_none()
    if not source:
        raise HTTPException(status_code=404, detail="Источник не найден")
    source.user_trust_score = trust_score
    await db.commit()
    await db.refresh(source)
    return {
        "id": str(source.id),
        "base_trust_score": round(source.trust_score, 3),
        "user_trust_score": round(source.user_trust_score, 3),
        "effective_trust_score": round(source.user_trust_score, 3),
    }


@router.delete("/sources/user/{source_id}/trust")
async def reset_user_trust(source_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(UserSource).where(
            UserSource.id == uuid_module.UUID(source_id),
            UserSource.is_builtin == False,
        )
    )
    source = result.scalar_one_or_none()
    if not source:
        raise HTTPException(status_code=404, detail="Источник не найден")
    source.user_trust_score = None
    await db.commit()
    return {"id": str(source.id), "base_trust_score": source.trust_score, "user_trust_score": None}


@router.delete("/sources/user/{source_id}")
async def delete_user_source(source_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(UserSource).where(
            UserSource.id == uuid_module.UUID(source_id),
            UserSource.is_builtin == False,
        )
    )
    source = result.scalar_one_or_none()
    if not source:
        raise HTTPException(status_code=404, detail="Источник не найден")
    await db.delete(source)
    await db.commit()
    _invalidate_feed_cache()
    return {"deleted": True}
