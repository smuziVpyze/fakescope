import whois
import re
import psycopg2
from datetime import datetime
from urllib.parse import urlparse
from app.modules.sources.domain_database import domain_db
from app.core.config import settings

def _get_sync_db_url() -> str:
    """postgresql+asyncpg://user:pass@host:port/db → host, port, user, pass, db"""
    url = settings.database_url.replace("postgresql+asyncpg://", "")
    # user:pass@host:port/db
    user_pass, rest = url.split("@")
    user, password = user_pass.split(":")
    host_port, dbname = rest.split("/")
    if ":" in host_port:
        host, port = host_port.split(":")
    else:
        host, port = host_port, "5432"
    return {"host": host, "port": int(port), "user": user, "password": password, "dbname": dbname}

class DomainAnalyzer:

    def _get_user_trust_sync(self, domain: str):
        """Синхронный запрос к БД через psycopg2."""
        try:
            parts = domain.split(".")
            domains_to_check = [domain]
            if len(parts) > 2:
                domains_to_check.append(".".join(parts[-2:]))

            params = _get_sync_db_url()
            conn = psycopg2.connect(**params)
            cur = conn.cursor()
            cur.execute(
                "SELECT trust_score, user_trust_score FROM user_sources WHERE domain = ANY(%s) LIMIT 1",
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

    def analyze(self, url: str) -> dict:
        try:
            domain = self._extract_domain(url)
            if not domain:
                return self._unknown()

            # 1. Пользовательский score имеет приоритет
            user_trust = self._get_user_trust_sync(domain)
            if user_trust is not None:
                trust_score = 1 - user_trust
                return {
                    "domain": domain,
                    "trust_score": round(trust_score, 3),
                    "explanation": f"Надёжный источник: {domain}",
                    "details": {"trust": user_trust, "from_user": True}
                }

            # 2. Наша база 67 доменов
            db_result = domain_db.get_trust(domain)
            if db_result["known"]:
                trust_score = 1 - db_result["trust"]
                return {
                    "domain": domain,
                    "trust_score": round(trust_score, 3),
                    "explanation": f"{db_result['label']}: {domain}",
                    "details": {"trust": db_result["trust"], "from_database": True}
                }

            # 3. WHOIS
            return self._whois_analyze(domain, url)

        except Exception as e:
            return self._unknown()

    def _extract_domain(self, url: str) -> str:
        try:
            parsed = urlparse(url)
            domain = parsed.netloc.lower()
            return re.sub(r'^www\.', '', domain)
        except:
            return ""

    def _whois_analyze(self, domain: str, url: str) -> dict:
        score = 0.5
        reasons = []

        if not url.startswith("https://"):
            score += 0.15
            reasons.append("нет SSL сертификата")

        try:
            w = whois.whois(domain)
            created = w.creation_date
            if isinstance(created, list):
                created = created[0]
            if created:
                age_days = (datetime.now() - created.replace(tzinfo=None)).days
                if age_days < 90:
                    score += 0.25
                    reasons.append(f"домен молодой ({age_days} дней)")
                elif age_days < 365:
                    score += 0.1
                    reasons.append("домен создан менее года назад")
                else:
                    score -= 0.1
                    reasons.append(f"домен существует {age_days // 365} лет")
        except:
            reasons.append("данные домена недоступны")

        score = max(0.0, min(1.0, score))
        explanation = ", ".join(reasons).capitalize() if reasons else "Домен проверен"
        return {
            "domain": domain,
            "trust_score": round(score, 3),
            "explanation": explanation,
            "details": {"from_database": False}
        }

    def _unknown(self) -> dict:
        return {
            "domain": "unknown",
            "trust_score": 0.5,
            "explanation": "Не удалось проверить источник",
            "details": {}
        }

domain_analyzer = DomainAnalyzer()
