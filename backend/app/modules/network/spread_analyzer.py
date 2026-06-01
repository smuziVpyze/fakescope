import re
import requests
import psycopg2
from datetime import datetime
from urllib.parse import urlparse, urljoin
from bs4 import BeautifulSoup
from deep_translator import GoogleTranslator
from app.core.config import settings
from app.modules.sources.domain_database import domain_db

# Домены которые не считаем "новостными ссылками"
_SKIP_DOMAINS = {
    "google.com", "youtube.com", "facebook.com", "twitter.com",
    "t.me", "vk.com", "instagram.com", "whatsapp.com",
    "wikipedia.org", "apple.com", "microsoft.com",
}


def _get_sync_db_params() -> dict:
    url = settings.database_url.replace("postgresql+asyncpg://", "")
    user_pass, rest = url.split("@")
    user, password = user_pass.split(":")
    host_port, dbname = rest.split("/")
    host, port = host_port.split(":") if ":" in host_port else (host_port, "5432")
    return {"host": host, "port": int(port), "user": user,
            "password": password, "dbname": dbname}


class SpreadAnalyzer:

    def __init__(self):
        self._translator = GoogleTranslator(source='auto', target='en')

    def analyze(self, title: str, url: str = None) -> dict:
        api_key = settings.news_api_key
        input_domain = self._extract_domain(url) if url else None

        if not api_key:
            return self._only_source(url, input_domain, title,
                                     "NewsAPI ключ не настроен — добавь NEWS_API_KEY в .env")

        # Шаг 1 — NewsAPI (перепечатки)
        query = self._build_query(title)
        print(f"🔍 NewsAPI: '{query}'")

        reprinted_nodes = {}
        try:
            resp = requests.get(
                "https://newsapi.org/v2/everything",
                params={"q": query, "sortBy": "publishedAt",
                        "pageSize": 20, "apiKey": api_key},
                timeout=10,
            )
            data = resp.json()
            if data.get("status") == "ok":
                articles = data.get("articles", [])
                print(f"✅ NewsAPI: найдено {len(articles)} статей")
                for article in articles:
                    article_url = article.get("url", "")
                    domain = self._extract_domain(article_url)
                    if not domain or domain in reprinted_nodes:
                        continue
                    published = self._parse_date(article.get("publishedAt", ""))
                    reprinted_nodes[domain] = {
                        "domain": domain,
                        "name": article.get("source", {}).get("name", domain),
                        "trust": self._domain_trust(domain),
                        "url": article_url,
                        "title": article.get("title", ""),
                        "published": published,
                        "relation": "reprinted",
                    }
        except Exception as e:
            print(f"⚠️ NewsAPI ошибка: {e}")

        # Шаг 2 — парсим ссылки из самой статьи (цитирования)
        cited_nodes = {}
        if url:
            cited_nodes = self._extract_cited_domains(url, input_domain)

        # Объединяем: cited имеет приоритет над reprinted
        nodes_map = {**reprinted_nodes}
        for domain, node in cited_nodes.items():
            if domain not in nodes_map:
                nodes_map[domain] = node
            else:
                # Домен найден в обоих — отмечаем как cited+reprinted
                nodes_map[domain]["relation"] = "both"

        # Добавляем исходный URL
        if input_domain and input_domain not in nodes_map:
            nodes_map[input_domain] = {
                "domain": input_domain,
                "name": input_domain,
                "trust": self._domain_trust(input_domain),
                "url": url,
                "title": title,
                "published": None,
                "relation": "original",
            }

        if not nodes_map:
            return self._only_source(url, input_domain, title,
                                     "Упоминаний в других источниках не найдено")

        # Определяем первоисточник
        all_nodes = list(nodes_map.values())
        with_date = sorted(
            [n for n in all_nodes if n["published"]],
            key=lambda x: x["published"]
        )
        without_date = [n for n in all_nodes if not n["published"]]

        if with_date:
            original = with_date[0]
            rest = with_date[1:] + without_date
        elif input_domain:
            original = next(
                (n for n in all_nodes if n["domain"] == input_domain),
                all_nodes[0]
            )
            rest = [n for n in all_nodes if n["domain"] != original["domain"]]
        else:
            original = all_nodes[0]
            rest = all_nodes[1:]

        # Строим граф — звезда от первоисточника
        nodes_out = [{
            "id": original["domain"],
            "label": original["name"],
            "trust": original["trust"],
            "is_original": True,
            "published_at": original["published"].isoformat() if original["published"] else None,
            "url": original["url"],
            "title": original["title"],
            "relation": "original",
        }]
        edges = []
        for node in rest:
            delay_str = self._calc_delay(original["published"], node["published"])
            nodes_out.append({
                "id": node["domain"],
                "label": node["name"],
                "trust": node["trust"],
                "is_original": False,
                "published_at": node["published"].isoformat() if node["published"] else None,
                "url": node["url"],
                "title": node["title"],
                "relation": node.get("relation", "reprinted"),
            })
            edges.append({
                "from": original["domain"],
                "to": node["domain"],
                "delay": delay_str,
                "type": node.get("relation", "reprinted"),  # reprinted / cited / both
            })

        reposts = len(rest)
        cited_count = sum(1 for n in rest if n.get("relation") in ("cited", "both"))
        summary_parts = [f"Первоисточник: {original['name']}"]
        if reposts > 0:
            summary_parts.append(f"Перепечатано {reposts} изданиями")
        if cited_count > 0:
            summary_parts.append(f"Процитировано {cited_count} раз")

        return {
            "original_url": original["url"],
            "original_domain": original["domain"],
            "original_name": original["name"],
            "nodes": nodes_out,
            "edges": edges,
            "spread_score": round(min(1.0, reposts / 10), 3),
            "summary": " · ".join(summary_parts),
            "cited_count": cited_count,
        }

    # ── парсинг ссылок из статьи ──────────────────────────────────────────

    def _extract_cited_domains(self, url: str, skip_domain: str = None) -> dict:
        """
        Скачиваем страницу и извлекаем все внешние ссылки на новостные домены.
        Возвращает dict domain → node с relation='cited'.
        """
        cited = {}
        try:
            resp = requests.get(
                url, timeout=5,
                headers={"User-Agent": "Mozilla/5.0"},
            )
            if resp.status_code != 200:
                print(f"⚠️ Парсинг ссылок: HTTP {resp.status_code} для {url}")
                return cited

            soup = BeautifulSoup(resp.text, "html.parser")

            # Ищем ссылки в теле статьи
            article_tag = (
                soup.find("article") or
                soup.find("div", class_=re.compile(r"article|content|body|text", re.I)) or
                soup.body
            )
            if not article_tag:
                return cited

            seen = set()
            for a in article_tag.find_all("a", href=True):
                href = a["href"].strip()
                # Приводим к абсолютному URL
                if href.startswith("/"):
                    href = urljoin(url, href)
                if not href.startswith("http"):
                    continue

                domain = self._extract_domain(href)
                if not domain or domain == skip_domain:
                    continue
                if domain in _SKIP_DOMAINS:
                    continue
                if domain in seen:
                    continue
                seen.add(domain)

                # Берём только домены с хотя бы одной точкой (не localhost и т.п.)
                if "." not in domain:
                    continue

                cited[domain] = {
                    "domain": domain,
                    "name": domain,
                    "trust": self._domain_trust(domain),
                    "url": href,
                    "title": a.get_text(strip=True)[:100] or domain,
                    "published": None,
                    "relation": "cited",
                }

            print(f"🔗 Найдено {len(cited)} цитируемых источников в статье")
        except Exception as e:
            print(f"⚠️ Парсинг ссылок не удался: {e}")
        return cited

    # ── вспомогательные ──────────────────────────────────────────────────

    def _build_query(self, title: str) -> str:
        try:
            translated = self._translator.translate(title[:200])
            print(f"🌐 Перевод: '{title[:50]}' → '{translated[:50]}'")
        except Exception as e:
            print(f"⚠️ Перевод не удался: {e}")
            translated = title
        clean = re.sub(r'[^\w\s]', ' ', translated)
        words = [w for w in clean.split() if len(w) > 3]
        return " ".join(words[:5]) if words else translated[:80]

    def _parse_date(self, pub_str: str):
        if not pub_str:
            return None
        try:
            return datetime.fromisoformat(pub_str.replace("Z", "+00:00"))
        except Exception:
            return None

    def _calc_delay(self, orig_published, node_published) -> str | None:
        if not orig_published or not node_published:
            return None
        delta = node_published - orig_published
        total_minutes = int(delta.total_seconds() / 60)
        if total_minutes < 0:
            return None
        if total_minutes < 60:
            return f"+{total_minutes}м"
        if total_minutes < 1440:
            return f"+{total_minutes // 60}ч"
        return f"+{total_minutes // 1440}д"

    def _get_user_trust(self, domain: str):
        try:
            parts = domain.split(".")
            domains_to_check = [domain]
            if len(parts) > 2:
                domains_to_check.append(".".join(parts[-2:]))
            conn = psycopg2.connect(**_get_sync_db_params())
            cur = conn.cursor()
            cur.execute(
                "SELECT trust_score, user_trust_score FROM user_sources "
                "WHERE domain = ANY(%s) LIMIT 1",
                (domains_to_check,)
            )
            row = cur.fetchone()
            cur.close()
            conn.close()
            if row:
                trust_score, user_trust_score = row
                return user_trust_score if user_trust_score is not None else trust_score
            return None
        except Exception as e:
            print(f"⚠️ user_trust lookup error: {e}")
            return None

    def _domain_trust(self, domain: str) -> float:
        user_trust = self._get_user_trust(domain)
        if user_trust is not None:
            return round(user_trust, 3)
        result = domain_db.get_trust(domain)
        if result["known"]:
            return result["trust"]
        return 0.5

    def _extract_domain(self, url: str) -> str:
        if not url:
            return ""
        try:
            domain = urlparse(url).netloc.lower()
            return re.sub(r'^www\.', '', domain)
        except Exception:
            return ""

    def _only_source(self, url, domain, title, message: str) -> dict:
        node_id = domain or "unknown"
        return {
            "original_url": url or "",
            "original_domain": node_id,
            "original_name": node_id,
            "nodes": [{
                "id": node_id,
                "label": node_id,
                "trust": self._domain_trust(node_id) if domain else 0.5,
                "is_original": True,
                "published_at": None,
                "url": url or "",
                "title": title,
                "relation": "original",
            }],
            "edges": [],
            "spread_score": 0.0,
            "summary": message,
            "cited_count": 0,
        }


spread_analyzer = SpreadAnalyzer()
