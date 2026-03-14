import faiss
import numpy as np
import requests
from bs4 import BeautifulSoup
from sentence_transformers import SentenceTransformer
import json
import os
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
INDEX_PATH = os.path.join(DATA_DIR, "factcheck.index")
FACTS_PATH = os.path.join(DATA_DIR, "facts.json")

SEED_FACTS = [
    {"text": "Учёные доказали что земля плоская и NASA скрывает правду", "verdict": "fake", "source_url": "https://medialeaks.ru", "title": "Земля плоская — фейк"},
    {"text": "Вакцины содержат чипы для слежки за людьми", "verdict": "fake", "source_url": "https://medialeaks.ru", "title": "Чипирование через вакцины — фейк"},
    {"text": "5G вышки вызывают коронавирус и рак", "verdict": "fake", "source_url": "https://medialeaks.ru", "title": "5G и болезни — фейк"},
    {"text": "Власти скрывают правду о метеорите который упадёт на землю", "verdict": "fake", "source_url": "https://medialeaks.ru", "title": "Метеорит — фейк"},
    {"text": "Центральный банк России повысил ключевую ставку", "verdict": "true", "source_url": "https://tass.ru", "title": "ЦБ повысил ставку — правда"},
    {"text": "ВОЗ объявила пандемию гриппа в 2024 году", "verdict": "fake", "source_url": "https://medialeaks.ru", "title": "ВОЗ пандемия гриппа — фейк"},
    {"text": "Правительство тайно добавляет фтор в воду для контроля населения", "verdict": "fake", "source_url": "https://medialeaks.ru", "title": "Фтор в воде — фейк"},
    {"text": "Учёные обнаружили лекарство от рака которое скрывают фармкомпании", "verdict": "fake", "source_url": "https://medialeaks.ru", "title": "Лекарство от рака скрывают — фейк"},
    {"text": "Россия запустила новый спутник связи", "verdict": "true", "source_url": "https://tass.ru", "title": "Запуск спутника — правда"},
    {"text": "Мигранты захватывают европейские города массово", "verdict": "fake", "source_url": "https://medialeaks.ru", "title": "Мигранты захватывают города — фейк"},
    {"text": "Депутаты проголосовали за повышение пенсионного возраста", "verdict": "true", "source_url": "https://rbc.ru", "title": "Пенсионный возраст — правда"},
    {"text": "Химтрейлы самолётов содержат яды для сокращения населения", "verdict": "fake", "source_url": "https://medialeaks.ru", "title": "Химтрейлы — фейк"},
]

class FactChecker:
    def __init__(self):
        self.model = None
        self.index = None
        self.facts = []
        self.vectors = []  # храним векторы для косинусной схожести
        self.loaded = False

    def load(self):
        print("⏳ Загружаем фактчек модуль...")
        os.makedirs(DATA_DIR, exist_ok=True)

        self.model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")

        if os.path.exists(FACTS_PATH):
            with open(FACTS_PATH, "r", encoding="utf-8") as f:
                self.facts = json.load(f)
            # Пересчитываем векторы
            if self.facts:
                texts = [f["text"] for f in self.facts]
                self.vectors = self.model.encode(texts, normalize_embeddings=True)
            print(f"✅ Фактчек база загружена: {len(self.facts)} записей")
        else:
            self.vectors = []
            self._seed()
            print(f"✅ Фактчек база создана: {len(self.facts)} записей")

        self.loaded = True

    def _seed(self):
        for fact in SEED_FACTS:
            vector = self.model.encode([fact["text"]], normalize_embeddings=True)[0]
            self.vectors.append(vector)
            self.facts.append({
                "text": fact["text"],
                "verdict": fact["verdict"],
                "source_url": fact["source_url"],
                "title": fact["title"],
            })
        self._save()

    def add_fact(self, text: str, verdict: str, source_url: str, title: str):
        vector = self.model.encode([text], normalize_embeddings=True)[0]
        self.vectors.append(vector)
        self.facts.append({
            "text": text[:500],
            "verdict": verdict,
            "source_url": source_url,
            "title": title,
        })
        self._save()

    def check(self, text: str) -> dict:
        if not self.loaded:
            self.load()

        if not self.facts:
            return {"found": False, "score": 0.5, "explanation": "База фактчека пуста", "matches": []}

        # Косинусная схожесть — правильный метод для sentence transformers
        query_vector = self.model.encode([text], normalize_embeddings=True)[0]
        vectors_matrix = np.array(self.vectors)
        similarities = np.dot(vectors_matrix, query_vector)  # косинусная схожесть

        # Топ 3 совпадения
        top_indices = np.argsort(similarities)[::-1][:3]
        matches = []
        for idx in top_indices:
            sim = float(similarities[idx])
            if sim > 0.5:  # порог 0.5 для косинусной схожести
                fact = self.facts[idx]
                matches.append({
                    "title": fact["title"],
                    "verdict": fact["verdict"],
                    "source_url": fact["source_url"],
                    "similarity": round(sim, 3),
                })

        if not matches:
            return {"found": False, "score": 0.5, "explanation": "Похожих проверенных фактов не найдено", "matches": []}

        best = matches[0]
        if best["verdict"] == "fake":
            score = 0.8
            explanation = f"Найдено похожее разоблачение: {best['title']}"
        else:
            score = 0.2
            explanation = f"Найдена похожая проверенная новость: {best['title']}"

        return {"found": True, "score": round(score, 3), "explanation": explanation, "matches": matches}

    def scrape_medialeaks(self, max_pages: int = 3):
        if not self.loaded:
            self.load()
        print("⏳ Парсим Medialeaks...")
        added = 0
        headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            "Accept-Language": "ru-RU,ru;q=0.9",
        }
        for page in range(1, max_pages + 1):
            try:
                url = f"https://medialeaks.ru/category/fake-news/page/{page}/"
                response = requests.get(url, headers=headers, timeout=15, verify=False)
                soup = BeautifulSoup(response.text, "html.parser")
                for article in soup.find_all("article"):
                    title_tag = article.find("h2") or article.find("h3")
                    link_tag = article.find("a", href=True)
                    if title_tag and link_tag:
                        self.add_fact(
                            text=title_tag.get_text(strip=True),
                            verdict="fake",
                            source_url=link_tag["href"],
                            title=title_tag.get_text(strip=True)
                        )
                        added += 1
            except Exception as e:
                print(f"Ошибка страницы {page}: {e}")
        print(f"✅ Добавлено {added} записей из Medialeaks")
        return added

    def _save(self):
        with open(FACTS_PATH, "w", encoding="utf-8") as f:
            json.dump(self.facts, f, ensure_ascii=False, indent=2)

factchecker = FactChecker()
