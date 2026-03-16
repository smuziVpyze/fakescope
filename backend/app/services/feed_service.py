import json
import redis
import hashlib
from app.modules.feed.rss_fetcher import rss_fetcher
from app.modules.nlp.analyzer import nlp_analyzer
from app.core.config import settings

# Подключение к Redis
redis_client = redis.from_url(settings.redis_url, decode_responses=True)

FEED_CACHE_KEY = "fakescope:feed:latest"
CACHE_TTL = 900  # 15 минут

class FeedService:

    def get_feed(self, force_refresh: bool = False) -> list:
        """Возвращает ленту — из кэша или свежую"""

        # Пробуем взять из Redis
        if not force_refresh:
            cached = redis_client.get(FEED_CACHE_KEY)
            if cached:
                print("📦 Лента из кэша")
                return json.loads(cached)

        # Если кэша нет — парсим и анализируем
        print("🔄 Обновляем ленту...")
        articles = rss_fetcher.fetch_all()
        analyzed = []

        for article in articles[:50]:  # анализируем топ 30
            text = article["title"]
            if article["summary"]:
                text = text + ". " + article["summary"]

            # Быстрый NLP анализ
            try:
                nlp = nlp_analyzer.analyze(text)
                article["fake_score"] = nlp["fake_score"]
                article["verdict"] = self._verdict(nlp["fake_score"])
                article["nlp_explanation"] = nlp["explanation"]
            except:
                article["fake_score"] = 0.5
                article["verdict"] = "unverified"
                article["nlp_explanation"] = ""

            analyzed.append(article)

        # Сохраняем в Redis на 15 минут
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
