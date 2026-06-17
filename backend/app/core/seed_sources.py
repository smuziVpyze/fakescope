from sqlalchemy import select, func
from app.core.database import AsyncSessionLocal
from app.models.db_models import BuiltinSource, DomainReputation
from app.modules.feed.rss_fetcher import RSS_SOURCES, _trust_label
from app.modules.sources.domain_database import RELIABLE_RU, UNRELIABLE_RU
from urllib.parse import urlparse
import re

DOMAIN_OVERRIDE = {
    "feeds.bbci.co.uk": "bbc.com",
    "russian.rt.com": "rt.com",
}

def _extract_domain(url: str) -> str:
    try:
        domain = urlparse(url).netloc.lower()
        return re.sub(r'^www\.', '', domain)
    except Exception:
        return url


async def seed_builtin_sources():
    async with AsyncSessionLocal() as db:
        count = await db.scalar(select(func.count()).select_from(BuiltinSource))
        if count and count > 0:
            return
        print("⏳ Сидируем встроенные источники...")
        seen = set()
        for s in RSS_SOURCES:
            rss_domain = _extract_domain(s["url"])
            domain = DOMAIN_OVERRIDE.get(rss_domain, rss_domain)
            if domain in seen:
                continue
            seen.add(domain)
            db.add(BuiltinSource(
                domain=domain,
                name=s["name"],
                rss_url=s["url"],
                trust_label=s.get("trust", "neutral"),
                enabled=True,
            ))
        await db.commit()
        print(f"✅ Встроенные источники засидированы: {len(seen)}")


async def seed_domain_reputation():
    async with AsyncSessionLocal() as db:
        count = await db.scalar(select(func.count()).select_from(DomainReputation))
        if count and count > 0:
            return
        print("⏳ Сидируем репутацию доменов...")
        n = 0
        for domain, trust in RELIABLE_RU.items():
            db.add(DomainReputation(domain=domain, trust_score=trust, reliable=True, source="ru_list"))
            n += 1
        for domain, trust in UNRELIABLE_RU.items():
            db.add(DomainReputation(domain=domain, trust_score=trust, reliable=False, source="ru_list"))
            n += 1
        await db.commit()
        print(f"✅ Репутация доменов засидирована: {n}")


async def seed_all():
    await seed_builtin_sources()
    await seed_domain_reputation()
