import feedparser
import requests
from bs4 import BeautifulSoup
from sentence_transformers import SentenceTransformer
import numpy as np
from datetime import datetime, timezone
from urllib.parse import urlparse
import re
import urllib3
urllib3.disable_warnings()

# Источники для поиска перепечаток
NEWS_SOURCES = [
    {"url": "https://tass.ru/rss/v2.xml",                    "name": "ТАСС",       "trust": 0.9},
    {"url": "https://ria.ru/export/rss2/archive/index.xml",  "name": "РИА",        "trust": 0.85},
    {"url": "https://rbc.ru/rss/news",                       "name": "РБК",        "trust": 0.85},
    {"url": "https://lenta.ru/rss/news",                     "name": "Лента.ру",   "trust": 0.7},
    {"url": "https://meduza.io/rss/all",                     "name": "Медуза",     "trust": 0.75},
    {"url": "https://nn.ru/rss/",                            "name": "НН.ру",      "trust": 0.5},
    {"url": "https://www.e1.ru/rss/news/",                   "name": "E1",         "trust": 0.5},
]

class SpreadAnalyzer:
    def __init__(self):
        self.model = None

    def _load_model(self):
        if not self.model:
            from app.modules.factcheck.checker import factchecker
            self.model = factchecker.model

    def analyze(self, url: str, title: str) -> dict:
        """Анализируем распространение новости по источникам"""
        self._load_model()

        # Вектор оригинальной новости
        query_vector = self.model.encode([title], normalize_embeddings=True)[0]

        # Парсим оригинальный источник
        original_domain = self._extract_domain(url)
        nodes = []
        edges = []

        # Добавляем оригинал
        nodes.append({
            "id": original_domain,
            "label": original_domain,
            "trust": self._domain_trust(original_domain),
            "is_original": True,
            "published_at": None,
            "url": url,
        })

        # Ищем похожие новости в других источниках
        print(f"🔍 Ищем перепечатки для: {title[:50]}...")

        for source in NEWS_SOURCES:
            if original_domain in source["url"]:
                continue  # пропускаем оригинальный источник

            try:
                feed = feedparser.parse(source["url"])
                for entry in feed.entries[:20]:
                    entry_title = entry.get("title", "")
                    if not entry_title:
                        continue

                    # Сравниваем заголовки
                    entry_vector = self.model.encode([entry_title], normalize_embeddings=True)[0]
                    similarity = float(np.dot(query_vector, entry_vector))

                    if similarity > 0.45:  # высокий порог — только реальные перепечатки
                        entry_url = entry.get("link", "")
                        entry_domain = self._extract_domain(entry_url)

                        # Парсим дату
                        published = None
                        if hasattr(entry, "published_parsed") and entry.published_parsed:
                            published = datetime(*entry.published_parsed[:6],
                                               tzinfo=timezone.utc).isoformat()

                        # Добавляем узел
                        if not any(n["id"] == entry_domain for n in nodes):
                            nodes.append({
                                "id": entry_domain,
                                "label": source["name"],
                                "trust": source["trust"],
                                "is_original": False,
                                "published_at": published,
                                "url": entry_url,
                                "similarity": round(similarity, 3),
                                "title": entry_title,
                            })

                        # Добавляем связь
                        edges.append({
                            "from": original_domain,
                            "to": entry_domain,
                            "similarity": round(similarity, 3),
                        })

            except Exception as e:
                continue

        print(f"✅ Найдено {len(nodes)} узлов, {len(edges)} связей")

        return {
            "original_url": url,
            "original_domain": original_domain,
            "nodes": nodes,
            "edges": edges,
            "spread_score": self._spread_score(nodes, edges),
            "summary": self._summary(nodes, edges, original_domain),
        }

    def _extract_domain(self, url: str) -> str:
        try:
            domain = urlparse(url).netloc.lower()
            return re.sub(r'^www\.', '', domain)
        except:
            return url

    def _domain_trust(self, domain: str) -> float:
        trusted = {"tass.ru": 0.9, "ria.ru": 0.85, "rbc.ru": 0.85,
                   "kommersant.ru": 0.8, "vedomosti.ru": 0.8,
                   "lenta.ru": 0.7, "meduza.io": 0.75}
        return trusted.get(domain, 0.5)

    def _spread_score(self, nodes: list, edges: list) -> float:
        """Чем больше перепечаток — тем выше скор распространения"""
        if len(nodes) <= 1:
            return 0.0
        return min(1.0, len(edges) / 10)

    def _summary(self, nodes: list, edges: list, original: str) -> str:
        if len(nodes) <= 1:
            return "Перепечаток не найдено"
        reposts = len(nodes) - 1
        return f"Новость перепечатана {reposts} {'источником' if reposts == 1 else 'источниками'}"

spread_analyzer = SpreadAnalyzer()
