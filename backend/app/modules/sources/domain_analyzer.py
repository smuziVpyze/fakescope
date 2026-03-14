import whois
import re
from datetime import datetime, timezone
from urllib.parse import urlparse

# База известных ненадёжных доменов
UNRELIABLE_DOMAINS = {
    "msk-news-24.ru", "pravda-news.ru", "realnews.ru",
    "infowars.com", "stopfake.org.ua", "antifake.ru",
    "news-front.info", "riafan.ru", "life.ru",
}

# База надёжных доменов
RELIABLE_DOMAINS = {
    "tass.ru", "ria.ru", "rbc.ru", "kommersant.ru",
    "reuters.com", "bbc.com", "bbc.co.uk", "ap.org",
    "interfax.ru", "vedomosti.ru", "meduza.io",
}

class DomainAnalyzer:

    def analyze(self, url: str) -> dict:
        try:
            domain = self._extract_domain(url)
            if not domain:
                return self._unknown()

            # Проверяем по базам
            if domain in RELIABLE_DOMAINS:
                return {
                    "domain": domain,
                    "trust_score": 0.1,  # низкий скор = надёжный
                    "explanation": f"Надёжный источник: {domain}",
                    "details": {"reliable": True}
                }

            if domain in UNRELIABLE_DOMAINS:
                return {
                    "domain": domain,
                    "trust_score": 0.9,  # высокий скор = ненадёжный
                    "explanation": f"Домен замечен в распространении фейков",
                    "details": {"unreliable": True}
                }

            # Проверяем через WHOIS
            return self._whois_analyze(domain, url)

        except Exception as e:
            return self._unknown()

    def _extract_domain(self, url: str) -> str:
        try:
            parsed = urlparse(url)
            domain = parsed.netloc.lower()
            # Убираем www.
            domain = re.sub(r'^www\.', '', domain)
            return domain
        except:
            return ""

    def _whois_analyze(self, domain: str, url: str) -> dict:
        score = 0.5  # начальный нейтральный скор
        details = {}
        reasons = []

        # Проверяем SSL
        has_ssl = url.startswith("https://")
        details["ssl"] = has_ssl
        if not has_ssl:
            score += 0.15
            reasons.append("нет SSL сертификата")

        # Проверяем возраст домена через WHOIS
        try:
            w = whois.whois(domain)
            created = w.creation_date
            if isinstance(created, list):
                created = created[0]

            if created:
                age_days = (datetime.now() - created.replace(tzinfo=None)).days
                details["age_days"] = age_days

                if age_days < 90:
                    score += 0.25
                    reasons.append(f"домен молодой ({age_days} дней)")
                elif age_days < 365:
                    score += 0.1
                    reasons.append(f"домен создан менее года назад")
                else:
                    score -= 0.1
                    reasons.append(f"домен существует {age_days // 365} лет")
        except:
            reasons.append("не удалось получить данные домена")

        score = max(0.0, min(1.0, score))

        explanation = ", ".join(reasons).capitalize() if reasons else "Домен проверен"

        return {
            "domain": domain,
            "trust_score": round(score, 3),
            "explanation": explanation,
            "details": details,
        }

    def _unknown(self) -> dict:
        return {
            "domain": "unknown",
            "trust_score": 0.5,
            "explanation": "Не удалось проверить источник",
            "details": {},
        }

domain_analyzer = DomainAnalyzer()
