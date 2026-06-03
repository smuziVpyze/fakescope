from fastapi import APIRouter
import psycopg2
from urllib.parse import urlparse
import re
from datetime import datetime, timedelta, timezone
from app.core.config import settings
from app.modules.sources.domain_database import domain_db

router = APIRouter()

def _get_db_params() -> dict:
    url = settings.database_url.replace("postgresql+asyncpg://", "")
    user_pass, rest = url.split("@")
    user, password = user_pass.split(":")
    host_port, dbname = rest.split("/")
    host, port = host_port.split(":") if ":" in host_port else (host_port, "5432")
    return {"host": host, "port": int(port), "user": user, "password": password, "dbname": dbname}

_DOMAIN_ALIASES = {
    "bbc.co.uk": "bbc.com",
    "feeds.bbci.co.uk": "bbc.com",
}

def _extract_domain(url: str) -> str:
    if not url:
        return ""
    try:
        domain = urlparse(url).netloc.lower()
        domain = re.sub(r'^www\.', '', domain)
        return _DOMAIN_ALIASES.get(domain, domain)
    except Exception:
        return ""

@router.get("/domains/{domain}/stats")
def get_domain_stats(domain: str):
    try:
        conn = psycopg2.connect(**_get_db_params())
        cur = conn.cursor()

        cur.execute("""
            SELECT verdict, confidence, created_at, input_url
            FROM analyses
            WHERE input_url IS NOT NULL
              AND created_at >= NOW() - INTERVAL '90 days'
        """)
        all_rows = cur.fetchall()
        cur.close()
        conn.close()

        def _domain_matches(url: str, domain: str) -> bool:
            d = _extract_domain(url)
            return d == domain or d.endswith('.' + domain)

        domain_rows = [
            (verdict, confidence, created_at)
            for verdict, confidence, created_at, url in all_rows
            if _domain_matches(url, domain)
        ]

        total = len(domain_rows)
        db_info = domain_db.get_trust(domain)

        # Пользовательский score
        try:
            conn3 = psycopg2.connect(**_get_db_params())
            cur3 = conn3.cursor()
            cur3.execute("SELECT user_trust_score FROM user_sources WHERE domain = %s LIMIT 1", (domain,))
            row3 = cur3.fetchone()
            cur3.close()
            conn3.close()
            user_score = float(row3[0]) if row3 and row3[0] is not None else None
        except Exception:
            user_score = None

        if total == 0:
            effective = user_score if user_score is not None else db_info["trust"]
            return {
                "domain": domain,
                "total_analyses": 0,
                "verdicts": {"true": 0, "fake": 0, "unverified": 0},
                "avg_confidence": None,
                "trust_score": db_info["trust"],
                "trust_score_dynamic": effective,
                "trend": [],
                "known": db_info["known"],
                "user_trust_score": user_score,
            }

        verdicts = {"true": 0, "fake": 0, "unverified": 0}
        for verdict, _, _ in domain_rows:
            if verdict in verdicts:
                verdicts[verdict] += 1

        avg_confidence = sum(c for _, c, _ in domain_rows) / total
        fake_ratio = verdicts["fake"] / total
        history_score = round(1.0 - fake_ratio, 3)
        base_score = db_info["trust"]
        effective_base = user_score if user_score is not None else base_score
        dynamic_trust = round(effective_base * 0.7 + history_score * 0.3, 3) if total >= 3 else effective_base

        now = datetime.now(timezone.utc)
        trend = []
        for i in range(29, -1, -1):
            day = now - timedelta(days=i)
            day_str = day.strftime("%Y-%m-%d")
            day_rows = [r for r in domain_rows if r[2].strftime("%Y-%m-%d") == day_str]
            if day_rows:
                day_fakes = sum(1 for r in day_rows if r[0] == "fake")
                day_trues = sum(1 for r in day_rows if r[0] == "true")
                day_unverified = sum(1 for r in day_rows if r[0] == "unverified")
                n = len(day_rows)
                trend.append({
                    "date": day_str,
                    "count": n,
                    "true_count": day_trues,
                    "fake_count": day_fakes,
                    "unverified_count": day_unverified,
                    "fake_ratio": round(day_fakes / n, 2),
                    "true_ratio": round(day_trues / n, 2),
                })

        return {
            "domain": domain,
            "total_analyses": total,
            "verdicts": verdicts,
            "avg_confidence": round(avg_confidence, 3),
            "trust_score": base_score,
            "trust_score_dynamic": dynamic_trust,
            "trend": trend,
            "known": db_info["known"],
            "user_trust_score": user_score,
        }

    except Exception as e:
        return {"error": str(e)}
