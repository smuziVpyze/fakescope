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
