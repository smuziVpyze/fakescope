import json
import asyncio
import hashlib
import redis
from sqlalchemy import select
from app.modules.feed.rss_fetcher import rss_fetcher, RSS_SOURCES
from app.modules.nlp.analyzer import nlp_analyzer
from app.modules.nlp.topic_classifier import topic_classifier
from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.models.db_models import UserSource, BuiltinSource

redis_client = redis.from_url(settings.redis_url, decode_responses=True)

FEED_CACHE_KEY = "fakescope:feed:latest"
CACHE_TTL = 900

SOURCE_NAME_TO_DOMAIN = {
    "ТАСС": "tass.ru",
    "РИА Новости": "ria.ru",
    "Коммерсант": "kommersant.ru",
    "Интерфакс": "interfax.ru",
    "Ведомости": "vedomosti.ru",
    "BBC Русская": "bbc.com",
    "Лента.ру": "lenta.ru",
    "Медуза": "meduza.io",
    "Медуза Новости": "meduza.io",
    "МК": "mk.ru",
    "АиФ": "aif.ru",
    "RT": "rt.com",
    "74.ру": "74.ru",
    "URA.RU": "ura.news",
}

class FeedService:

    async def _get_active_builtin_sources(self):
        try:
            async with AsyncSessionLocal() as db:
                result = await db.execute(
                    select(BuiltinSource).where(BuiltinSource.enabled == True)
                )
                return [
                    {"url": s.rss_url, "name": s.name, "trust": s.trust_label}
                    for s in result.scalars().all()
                    if s.rss_url
                ]
        except Exception as e:
            print(f"⚠️ Не удалось загрузить встроенные источники: {e}")
            return []

    async def _get_user_sources(self):
        try:
            async with AsyncSessionLocal() as db:
                result = await db.execute(
                    select(UserSource).where(
                        UserSource.enabled == True,
                        UserSource.rss_url != None,
                        UserSource.rss_url != "",
                        UserSource.is_builtin == False,
                    )
                )
                return result.scalars().all()
        except Exception as e:
            print(f"⚠️ Не удалось загрузить пользовательские источники: {e}")
            return []

    async def get_feed_async(self, force_refresh: bool = False) -> list:
        if not force_refresh:
            cached = redis_client.get(FEED_CACHE_KEY)
            if cached:
                print("📦 Лента из кэша")
                return json.loads(cached)

        print("🔄 Обновляем ленту...")

        # Берём активные встроенные источники из БД
        active_sources = await self._get_active_builtin_sources()
        articles = rss_fetcher.fetch_active(active_sources)

        # Подмешиваем пользовательские источники
        user_sources = await self._get_user_sources()
        for src in user_sources:
            effective_trust = src.user_trust_score if src.user_trust_score is not None else src.trust_score
            user_articles = rss_fetcher.fetch_user_source(
                rss_url=src.rss_url,
                name=src.name,
                trust_score=effective_trust,
            )
            articles.extend(user_articles)
            print(f"  [user] {src.name}: {len(user_articles)} новостей")

        articles.sort(key=lambda x: x["published_at"], reverse=True)

        analyzed = []
        for article in articles[:50]:
            text = article["title"]

            try:
                nlp = nlp_analyzer.analyze(text)
                article["fake_score"] = nlp["fake_score"]
                article["verdict"] = self._verdict(nlp["fake_score"])
                article["nlp_explanation"] = nlp["explanation"]
            except:
                article["fake_score"] = 0.5
                article["verdict"] = "unverified"
                article["nlp_explanation"] = ""

            try:
                topic = topic_classifier.classify(text)
                article["category"] = topic["category"]
                article["category_ru"] = topic["category_ru"]
                article["category_emoji"] = topic["category_emoji"]
            except:
                article["category"] = "society"
                article["category_ru"] = "общество"
                article["category_emoji"] = "👥"

            analyzed.append(article)

        redis_client.setex(FEED_CACHE_KEY, CACHE_TTL, json.dumps(analyzed, ensure_ascii=False))
        print(f"✅ Лента обновлена: {len(analyzed)} новостей")
        return analyzed

    def _verdict(self, score: float) -> str:
        if score >= 0.65:   return "fake"
        elif score >= 0.35: return "unverified"
        else:               return "true"

    def get_article_hash(self, url: str) -> str:
        return hashlib.md5(url.encode()).hexdigest()

feed_service = FeedService()
