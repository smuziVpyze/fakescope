import re
import feedparser
import psycopg2
from datetime import datetime, timezone
from urllib.parse import urlparse, quote
from app.core.config import settings
from app.modules.sources.domain_database import domain_db

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

    def analyze(self, title: str, url: str = None) -> dict:
        input_domain = self._extract_domain(url) if url else None

        # Строим поисковый запрос — первые 4 значимых слова
        query = self._build_query(title)
        print(f"🔍 Google News RSS: '{query}'")

        # Запрашиваем Google News RSS
        articles = self._fetch_gnews(query)

        if not articles:
            return self._only_source(url, input_domain, title,
                                     "Новость не найдена в других источниках")

        # Сортируем по дате
        articles.sort(key=lambda a: a["published"] or datetime.min.replace(tzinfo=timezone.utc))

        # Первоисточник — самая ранняя статья
        original = articles[0]

        # Если передан URL — проверяем совпадает ли домен с первоисточником
        if input_domain and input_domain != original["domain"]:
            # Ищем статью от нашего домена
            our = next((a for a in articles if a["domain"] == input_domain), None)
            if our:
                original = our
                articles = [a for a in articles if a["domain"] != input_domain]
                articles.insert(0, original)

        orig_published = original["published"]
        rest = articles[1:]

        # Группируем перепечатки по временным интервалам
        def time_group(pub):
            if not pub or not orig_published:
                return 3
            delta_hours = (pub - orig_published).total_seconds() / 3600
            if delta_hours < 2:   return 1  # 0-2ч
            if delta_hours < 6:   return 2  # 2-6ч
            if delta_hours < 24:  return 3  # 6-24ч
            return 4                         # 1д+

        nodes_out = []
        edges = []

        # Первоисточник
        nodes_out.append({
            "id": original["domain"],
            "label": original["name"],
            "trust": self._domain_trust(original["domain"]),
            "is_original": True,
            "published_at": original["published"].isoformat() if original["published"] else None,
            "url": original["url"],
            "title": original["title"],
            "relation": "original",
            "time_group": 0,
        })

        seen_domains = {original["domain"]}

        for node in rest:
            domain = node["domain"]
            if domain in seen_domains:
                continue
            seen_domains.add(domain)

            pub = node["published"]
            delay_str = self._calc_delay(orig_published, pub)
            group = time_group(pub)

            nodes_out.append({
                "id": domain,
                "label": node["name"],
                "trust": self._domain_trust(domain),
                "is_original": False,
                "published_at": pub.isoformat() if pub else None,
                "url": node["url"],
                "title": node["title"],
                "relation": "reprinted",
                "time_group": group,
            })

            edges.append({
                "from": original["domain"],
                "to": domain,
                "delay": delay_str,
                "type": "reprinted",
            })

        reposts = len(nodes_out) - 1
        summary_parts = [f"Первоисточник: {original['name']}"]
        if reposts > 0:
            summary_parts.append(f"Перепечатано {reposts} изданиями")

        return {
            "original_url": original["url"],
            "original_domain": original["domain"],
            "original_name": original["name"],
            "nodes": nodes_out,
            "edges": edges,
            "spread_score": round(min(1.0, reposts / 10), 3),
            "summary": " · ".join(summary_parts),
            "cited_count": 0,
        }

    def _fetch_gnews(self, query: str) -> list:
        try:
            from datetime import datetime, timedelta
            after = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
            encoded = quote(query + f' after:{after}')
            rss_url = f"https://news.google.com/rss/search?q={encoded}&hl=ru&gl=RU&ceid=RU:ru"
            feed = feedparser.parse(rss_url)
            articles = []
            for entry in feed.entries[:20]:
                pub = None
                if entry.get("published"):
                    try:
                        from email.utils import parsedate_to_datetime
                        pub = parsedate_to_datetime(entry.published)
                    except Exception:
                        pass

                source = entry.get("source", {})
                source_url = source.get("href", "") if source else ""
                name = source.get("title") if source else None

                # Берём домен из source.href, а не из google redirect URL
                domain = self._extract_domain(source_url)
                if not domain or domain in _SKIP_DOMAINS:
                    continue
                if not name:
                    name = domain

                # Реальный URL статьи — source.href (главная страница источника)
                # Для графа достаточно, точный URL требует редиректа
                url = source_url

                articles.append({
                    "domain": domain,
                    "name": name,
                    "url": url,
                    "title": entry.get("title", ""),
                    "published": pub,
                })
            print(f"📰 Google News: найдено {len(articles)} статей")
            return articles
        except Exception as e:
            print(f"⚠️ Google News RSS ошибка: {e}")
            return []

    def _build_query(self, title: str) -> str:
        # Используем полный заголовок для точного поиска
        return title[:150]

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
                "time_group": 0,
            }],
            "edges": [],
            "spread_score": 0.0,
            "summary": message,
            "cited_count": 0,
        }


spread_analyzer = SpreadAnalyzer()
