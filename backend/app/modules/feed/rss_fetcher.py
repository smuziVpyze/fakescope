import feedparser
from datetime import datetime, timezone
from typing import List, Dict

RSS_SOURCES = [
    {"url": "https://tass.ru/rss/v2.xml",                        "name": "ТАСС",             "trust": "reliable"},
    {"url": "https://rbc.ru/rss/news",                           "name": "РБК",              "trust": "reliable"},
    {"url": "https://ria.ru/export/rss2/archive/index.xml",      "name": "РИА",              "trust": "reliable"},
    {"url": "https://lenta.ru/rss/news",                         "name": "Лента.ру",         "trust": "neutral"},
    {"url": "https://meduza.io/rss/all",                         "name": "Медуза",           "trust": "neutral"},
    {"url": "https://nn.ru/rss/",                                "name": "НН.ру",            "trust": "neutral"},
    {"url": "https://www.e1.ru/rss/news/",                       "name": "E1 Екатеринбург",  "trust": "neutral"},
]

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

    def fetch_all(self) -> List[Dict]:
        all_articles = []
        for source in RSS_SOURCES:
            articles = self.fetch_source(source)
            all_articles.extend(articles)
            print(f"  {source['name']}: {len(articles)} новостей")
        all_articles.sort(key=lambda x: x["published_at"], reverse=True)
        return all_articles

rss_fetcher = RSSFetcher()
