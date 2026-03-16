import feedparser
import numpy as np
from datetime import datetime, timezone
from urllib.parse import urlparse
import re
import urllib3
urllib3.disable_warnings()

NEWS_SOURCES = [
    {"url": "https://tass.ru/rss/v2.xml",                  "name": "ТАСС",         "trust": 0.95},
    {"url": "https://ria.ru/export/rss2/archive/index.xml", "name": "РИА Новости",  "trust": 0.9},
    {"url": "https://www.kommersant.ru/RSS/news.xml",       "name": "Коммерсант",   "trust": 0.88},
    {"url": "https://interfax.ru/rss.asp",                  "name": "Интерфакс",    "trust": 0.9},
    {"url": "https://www.vedomosti.ru/rss/news",            "name": "Ведомости",    "trust": 0.87},
    {"url": "https://feeds.bbci.co.uk/russian/rss.xml",    "name": "BBC Русская",  "trust": 0.92},
    {"url": "https://rss.dw.com/rdf/rss-ru-all",           "name": "DW Русская",   "trust": 0.9},
    {"url": "https://lenta.ru/rss/news",                   "name": "Лента.ру",     "trust": 0.72},
    {"url": "https://meduza.io/rss/all",                   "name": "Медуза",       "trust": 0.78},
    {"url": "https://www.mk.ru/rss/index.xml",             "name": "МК",           "trust": 0.6},
    {"url": "https://aif.ru/rss/news",                     "name": "АиФ",          "trust": 0.62},
    {"url": "https://russian.rt.com/rss",                  "name": "RT",           "trust": 0.55},
    {"url": "https://74.ru/rss/",                          "name": "74.ру",        "trust": 0.5},
    {"url": "https://ura.news/rss",                        "name": "URA.RU",       "trust": 0.55},
]

class SpreadAnalyzer:
    def __init__(self):
        self.model = None

    def _load_model(self):
        if not self.model:
            from app.modules.factcheck.checker import factchecker
            self.model = factchecker.model

    def analyze(self, title: str, url: str = None) -> dict:
        """
        Анализируем распространение.
        url — опционально, если есть добавляем как один из источников.
        title — текст или заголовок новости для поиска.
        """
        self._load_model()

        # Берём первые 200 символов как поисковый запрос
        search_query = title[:200]
        query_vector = self.model.encode([search_query], normalize_embeddings=True)[0]

        input_domain = self._extract_domain(url) if url else None

        # Собираем все похожие публикации
        all_matches = []

        for source in NEWS_SOURCES:
            try:
                feed = feedparser.parse(source["url"])
                for entry in feed.entries[:20]:
                    entry_title = entry.get("title", "")
                    if not entry_title:
                        continue

                    entry_vector = self.model.encode([entry_title], normalize_embeddings=True)[0]
                    similarity = float(np.dot(query_vector, entry_vector))

                    if similarity > 0.45:
                        entry_url = entry.get("link", "")
                        entry_domain = self._extract_domain(entry_url)

                        published = None
                        if hasattr(entry, "published_parsed") and entry.published_parsed:
                            published = datetime(*entry.published_parsed[:6], tzinfo=timezone.utc)

                        all_matches.append({
                            "domain": entry_domain,
                            "name": source["name"],
                            "trust": source["trust"],
                            "url": entry_url,
                            "title": entry_title,
                            "published": published,
                            "similarity": round(similarity, 3),
                        })
            except:
                continue

        # Если есть URL — добавляем его если не нашли в RSS
        if input_domain and not any(m["domain"] == input_domain for m in all_matches):
            all_matches.append({
                "domain": input_domain,
                "name": input_domain,
                "trust": self._domain_trust(input_domain),
                "url": url,
                "title": title,
                "published": None,
                "similarity": 1.0,
            })

        if not all_matches:
            return self._empty(url or "", input_domain or "unknown")

        # Находим первоисточник по дате
        matches_with_date = [m for m in all_matches if m["published"]]
        matches_without_date = [m for m in all_matches if not m["published"]]

        if matches_with_date:
            matches_with_date.sort(key=lambda x: x["published"])
            original = matches_with_date[0]
            rest = matches_with_date[1:] + matches_without_date
        else:
            # Нет дат — если есть URL берём его, иначе первый найденный
            if input_domain:
                original = next((m for m in all_matches if m["domain"] == input_domain), all_matches[0])
            else:
                original = all_matches[0]
            rest = [m for m in all_matches if m["domain"] != original["domain"]]

        # Убираем дубли по домену
        seen = {original["domain"]}
        unique_rest = []
        for m in rest:
            if m["domain"] not in seen:
                seen.add(m["domain"])
                unique_rest.append(m)

        nodes = [{
            "id": original["domain"],
            "label": original["name"],
            "trust": original["trust"],
            "is_original": True,
            "published_at": original["published"].isoformat() if original["published"] else None,
            "url": original["url"],
            "title": original["title"],
        }]

        edges = []
        for m in unique_rest:
            nodes.append({
                "id": m["domain"],
                "label": m["name"],
                "trust": m["trust"],
                "is_original": False,
                "published_at": m["published"].isoformat() if m["published"] else None,
                "url": m["url"],
                "title": m["title"],
                "similarity": m["similarity"],
            })
            edges.append({
                "from": original["domain"],
                "to": m["domain"],
                "similarity": m["similarity"],
            })

        reposts = len(unique_rest)
        if reposts > 0:
            summary = f"Первоисточник: {original['name']} · Перепечатано {reposts} {'изданием' if reposts == 1 else 'изданиями'}"
        else:
            summary = f"Первоисточник: {original['name']} · Перепечаток не найдено"

        return {
            "original_url": original["url"],
            "original_domain": original["domain"],
            "original_name": original["name"],
            "nodes": nodes,
            "edges": edges,
            "spread_score": min(1.0, reposts / 10),
            "summary": summary,
        }

    def _extract_domain(self, url: str) -> str:
        try:
            domain = urlparse(url).netloc.lower()
            return re.sub(r'^www\.', '', domain)
        except:
            return url

    def _domain_trust(self, domain: str) -> float:
        trusted = {
            "tass.ru": 0.9, "ria.ru": 0.85, "rbc.ru": 0.85,
            "kommersant.ru": 0.85, "vedomosti.ru": 0.8,
            "iz.ru": 0.7, "lenta.ru": 0.7, "gazeta.ru": 0.65,
            "meduza.io": 0.75, "nn.ru": 0.5, "e1.ru": 0.5,
        }
        return trusted.get(domain, 0.5)

    def _empty(self, url: str, domain: str) -> dict:
        return {
            "original_url": url,
            "original_domain": domain,
            "original_name": domain,
            "nodes": [{"id": domain, "label": domain, "trust": 0.5,
                       "is_original": True, "published_at": None, "url": url}],
            "edges": [],
            "spread_score": 0.0,
            "summary": "Новость не найдена в отслеживаемых источниках",
        }

spread_analyzer = SpreadAnalyzer()
