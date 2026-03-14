import json
import os
import requests
import urllib3
urllib3.disable_warnings()

DATA_PATH = os.path.join(os.path.dirname(__file__), "domains.json")

# Публичные списки ненадёжных доменов
FAKE_NEWS_LISTS = [
    # Список от исследователей фейковых новостей (GitHub)
    "https://raw.githubusercontent.com/nickmvincent/fake-news-gist/master/fakenewssites.txt",
    # Список пропаганды и дезинформации
    "https://raw.githubusercontent.com/proppy/fake-news/master/sites.txt",
]

# Надёжные русскоязычные источники
RELIABLE_RU = {
    "tass.ru": 0.95,
    "ria.ru": 0.9,
    "rbc.ru": 0.88,
    "kommersant.ru": 0.88,
    "vedomosti.ru": 0.87,
    "interfax.ru": 0.9,
    "iz.ru": 0.75,
    "lenta.ru": 0.72,
    "gazeta.ru": 0.7,
    "meduza.io": 0.78,
    "novayagazeta.ru": 0.75,
    "fontanka.ru": 0.72,
    "znak.com": 0.7,
    "ura.news": 0.65,
    "74.ru": 0.65,
    "nn.ru": 0.65,
    "e1.ru": 0.65,
    "ngs.ru": 0.65,
    "kp.ru": 0.6,
    "mk.ru": 0.6,
    "aif.ru": 0.62,
    "russiatoday.ru": 0.55,
    "rt.com": 0.55,
    "bbc.com": 0.92,
    "reuters.com": 0.95,
    "ap.org": 0.95,
    "afp.com": 0.92,
}

# Ненадёжные русскоязычные источники (известные фейк-сайты)
UNRELIABLE_RU = {
    "riafan.ru": 0.15,
    "life.ru": 0.25,
    "rambler.ru": 0.4,
    "nation-news.ru": 0.1,
    "politros.com": 0.1,
    "news-front.info": 0.1,
    "alternatio.org": 0.1,
    "antifashist.com": 0.1,
    "anna-news.info": 0.15,
    "colonelcassad.livejournal.com": 0.2,
    "rusvesna.su": 0.1,
    "inforeactor.ru": 0.2,
    "topcor.ru": 0.15,
    "tsargrad.tv": 0.2,
    "pravda.ru": 0.25,
    "dni.ru": 0.2,
    "km.ru": 0.2,
    "zavtra.ru": 0.25,
    "nakanune.ru": 0.2,
    "regnum.ru": 0.3,
    "inosmi.ru": 0.35,
    "vz.ru": 0.3,
    "ukraina.ru": 0.15,
    "novorosinform.org": 0.1,
    "southfront.org": 0.1,
    "aurora.network": 0.1,
    "ren.tv": 0.3,
    "russia.tv": 0.3,
    "1tv.ru": 0.35,
    "ntv.ru": 0.35,
    "russia-insider.com": 0.1,
    "strategic-culture.org": 0.1,
    "globalresearch.ca": 0.15,
    "21wire.tv": 0.1,
    "zerohedge.com": 0.2,
    "infowars.com": 0.05,
    "naturalnews.com": 0.05,
    "beforeitsnews.com": 0.05,
    "yournewswire.com": 0.05,
    "worldnewsdailyreport.com": 0.05,
}

class DomainDatabase:
    def __init__(self):
        self.domains = {}
        self.loaded = False

    def load(self):
        """Загружаем базу доменов"""
        if os.path.exists(DATA_PATH):
            with open(DATA_PATH, "r") as f:
                self.domains = json.load(f)
            print(f"✅ База доменов загружена: {len(self.domains)} записей")
        else:
            self._build()
        self.loaded = True

    def _build(self):
        """Строим базу из всех источников"""
        print("⏳ Строим базу доменов...")

        # Добавляем надёжные русскоязычные
        for domain, trust in RELIABLE_RU.items():
            self.domains[domain] = {"trust": trust, "reliable": True}

        # Добавляем ненадёжные русскоязычные
        for domain, trust in UNRELIABLE_RU.items():
            self.domains[domain] = {"trust": trust, "reliable": False}

        # Пробуем загрузить публичные списки
        for url in FAKE_NEWS_LISTS:
            try:
                resp = requests.get(url, timeout=10, verify=False)
                for line in resp.text.splitlines():
                    domain = line.strip().lower()
                    if domain and "." in domain and domain not in self.domains:
                        self.domains[domain] = {"trust": 0.1, "reliable": False}
            except Exception as e:
                print(f"  Не удалось загрузить {url}: {e}")

        self._save()
        print(f"✅ База доменов построена: {len(self.domains)} записей")

    def get_trust(self, domain: str) -> dict:
        """Возвращает данные о домене"""
        if not self.loaded:
            self.load()

        # Убираем www.
        domain = domain.lower().replace("www.", "")

        if domain in self.domains:
            data = self.domains[domain]
            trust = data["trust"]
            if trust >= 0.8:
                label = "Надёжный источник"
            elif trust >= 0.5:
                label = "Нейтральный источник"
            else:
                label = "Ненадёжный источник"
            return {
                "trust": trust,
                "known": True,
                "label": label,
            }

        return {
            "trust": 0.5,
            "known": False,
            "label": "Неизвестный источник",
        }

    def add_domain(self, domain: str, trust: float):
        """Добавляем новый домен"""
        self.domains[domain] = {"trust": trust, "reliable": trust >= 0.5}
        self._save()

    def _save(self):
        with open(DATA_PATH, "w") as f:
            json.dump(self.domains, f, ensure_ascii=False, indent=2)

    @property
    def total(self):
        return len(self.domains)

domain_db = DomainDatabase()
