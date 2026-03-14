import whois
import re
from datetime import datetime
from urllib.parse import urlparse
from app.modules.sources.domain_database import domain_db

class DomainAnalyzer:

    def analyze(self, url: str) -> dict:
        try:
            domain = self._extract_domain(url)
            if not domain:
                return self._unknown()

            # Проверяем в базе
            db_result = domain_db.get_trust(domain)

            if db_result["known"]:
                trust_score = 1 - db_result["trust"]  # инвертируем — высокое доверие = низкий fake score
                return {
                    "domain": domain,
                    "trust_score": round(trust_score, 3),
                    "explanation": f"{db_result['label']}: {domain}",
                    "details": {"trust": db_result["trust"], "from_database": True}
                }

            # Неизвестный домен — проверяем через WHOIS
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

        has_ssl = url.startswith("https://")
        if not has_ssl:
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
