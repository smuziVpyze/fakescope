import feedparser
from datetime import datetime, timezone
from typing import List, Dict
from concurrent.futures import ThreadPoolExecutor, as_completed

RSS_SOURCES = [
    {"url": "https://tass.ru/rss/v2.xml",                  "name": "ТАСС",          "trust": "reliable"},
    {"url": "https://ria.ru/export/rss2/archive/index.xml", "name": "РИА Новости",   "trust": "reliable"},
    {"url": "https://www.kommersant.ru/RSS/news.xml",       "name": "Коммерсант",    "trust": "reliable"},
    {"url": "https://interfax.ru/rss.asp",                  "name": "Интерфакс",     "trust": "reliable"},
    {"url": "https://www.vedomosti.ru/rss/news",            "name": "Ведомости",     "trust": "reliable"},
    {"url": "https://feeds.bbci.co.uk/russian/rss.xml",    "name": "BBC Русская",   "trust": "reliable"},
    {"url": "https://lenta.ru/rss/news",                   "name": "Лента.ру",      "trust": "neutral"},
    {"url": "https://meduza.io/rss/all",                   "name": "Медуза",        "trust": "neutral"},
    {"url": "https://meduza.io/rss/news",                  "name": "Медуза Новости","trust": "neutral"},
    {"url": "https://www.mk.ru/rss/index.xml",             "name": "МК",            "trust": "neutral"},
    {"url": "https://aif.ru/rss/news",                     "name": "АиФ",           "trust": "neutral"},
    {"url": "https://russian.rt.com/rss",                  "name": "RT",            "trust": "neutral"},
    {"url": "https://74.ru/rss/",                          "name": "74.ру",         "trust": "neutral"},
    {"url": "https://ura.news/rss",                        "name": "URA.RU",        "trust": "neutral"},
]

def _trust_label(score: float) -> str:
    if score >= 0.75:
        return "reliable"
    elif score >= 0.5:
        return "neutral"
    else:
        return "unreliable"

class RSSFetcher:

    def fetch_source(self, source: Dict) -> List[Dict]:
        try:
            feed = feedparser.parse(source["url"])
            articles = []
            for entry in feed.entries[:10]:
                published = None
                if hasattr(entry, "published_parsed") and entry.published_parsed:
                    published = datetime(*entry.published_parsed[:6], tzinfo=timezone.utc)
                else:
                    published = datetime.now(timezone.utc)
                articles.append({
                    "title": entry.get("title", ""),
                    "url": entry.get("link", ""),
                    "summary": entry.get("summary", "")[:500],
                    "source_name": source["name"],
                    "source_trust": source["trust"],
                    "published_at": published.isoformat(),
                })
            return articles
        except Exception as e:
            print(f"Ошибка парсинга {source['name']}: {e}")
            return []

    def fetch_user_source(self, rss_url: str, name: str, trust_score: float) -> List[Dict]:
        try:
            feed = feedparser.parse(rss_url)
            articles = []
            trust_label = _trust_label(trust_score)
            for entry in feed.entries[:10]:
                published = None
                if hasattr(entry, "published_parsed") and entry.published_parsed:
                    published = datetime(*entry.published_parsed[:6], tzinfo=timezone.utc)
                else:
                    published = datetime.now(timezone.utc)
                articles.append({
                    "title": entry.get("title", ""),
                    "url": entry.get("link", ""),
                    "summary": entry.get("summary", "")[:500],
                    "source_name": name,
                    "source_trust": trust_label,
                    "published_at": published.isoformat(),
                    "is_user_source": True,
                })
            return articles
        except Exception as e:
            print(f"Ошибка парсинга пользовательского источника '{name}': {e}")
            return []

    def fetch_active(self, sources: list) -> List[Dict]:
        """Парсит источники параллельно через ThreadPoolExecutor."""
        all_articles = []
        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = {executor.submit(self.fetch_source, src): src for src in sources}
            for future in as_completed(futures):
                src = futures[future]
                try:
                    articles = future.result()
                    all_articles.extend(articles)
                    print(f"  {src['name']}: {len(articles)} новостей")
                except Exception as e:
                    print(f"  {src['name']}: ошибка — {e}")
        all_articles.sort(key=lambda x: x["published_at"], reverse=True)
        return all_articles

    def fetch_all(self) -> List[Dict]:
        return self.fetch_active(RSS_SOURCES)

rss_fetcher = RSSFetcher()
