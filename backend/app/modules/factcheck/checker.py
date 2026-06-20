import faiss
import numpy as np
import psycopg2
from sentence_transformers import SentenceTransformer
import os
from app.core.config import settings

def _get_db_params() -> dict:
    url = settings.database_url.replace("postgresql+asyncpg://", "")
    user_pass, rest = url.split("@")
    user, password = user_pass.split(":")
    host_port, dbname = rest.split("/")
    host, port = host_port.split(":") if ":" in host_port else (host_port, "5432")
    return {"host": host, "port": int(port), "user": user,
            "password": password, "dbname": dbname}

class FactChecker:
    def __init__(self):
        self.model = None
        self.index = None
        self.facts = []
        self.vectors = []
        self.loaded = False

    def load(self):
        print("⏳ Загружаем фактчек модуль...")
        self.model = SentenceTransformer("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")
        self._load_from_db()
        self.loaded = True

    def _load_from_db(self):
        try:
            conn = psycopg2.connect(**_get_db_params())
            cur = conn.cursor()
            cur.execute("SELECT text, title, verdict, source_url FROM factcheck_entries ORDER BY created_at")
            rows = cur.fetchall()
            cur.close()
            conn.close()

            if rows:
                self.facts = [
                    {"text": r[0], "title": r[1], "verdict": r[2], "source_url": r[3]}
                    for r in rows
                ]
                texts = [f["text"] for f in self.facts]
                print(f"⏳ Энкодим {len(texts)} записей...")
                self.vectors = self.model.encode(texts, normalize_embeddings=True, show_progress_bar=True, batch_size=64)
                self._build_index()
                print(f"✅ Фактчек база загружена: {len(self.facts)} записей")
            else:
                print("⚠️ Фактчек база пуста — запусти populate_faiss.py")
        except Exception as e:
            print(f"⚠️ Ошибка загрузки фактчек базы: {e}")
            self.facts = []
            self.vectors = []


    def _insert_db(self, text: str, verdict: str, source_url: str, title: str):
        try:
            conn = psycopg2.connect(**_get_db_params())
            cur = conn.cursor()
            cur.execute(
                """INSERT INTO factcheck_entries (id, text, title, verdict, source_url, created_at)
                   VALUES (gen_random_uuid(), %s, %s, %s, %s, NOW())
                   ON CONFLICT (text) DO NOTHING""",
                (text[:500], title[:500] if title else None, verdict, source_url)
            )
            conn.commit()
            cur.close()
            conn.close()
        except Exception as e:
            print(f"⚠️ Ошибка вставки в БД: {e}")

    def _build_index(self):
        if not len(self.vectors):
            return
        vectors = np.array(self.vectors).astype("float32")
        dim = vectors.shape[1]
        self.index = faiss.IndexFlatIP(dim)
        self.index.add(vectors)

    def add_fact(self, text: str, verdict: str, source_url: str, title: str):
        self._insert_db(text, verdict, source_url, title)
        vector = self.model.encode([text], normalize_embeddings=True)[0]
        if isinstance(self.vectors, list):
            self.vectors.append(vector)
        else:
            self.vectors = np.vstack([self.vectors, vector.reshape(1, -1)])
        self.facts.append({
            "text": text[:500],
            "verdict": verdict,
            "source_url": source_url,
            "title": title[:100] if title else None,
        })
        self._build_index()

    def check(self, text: str) -> dict:
        if not self.loaded:
            self.load()

        if not self.facts:
            return {"found": False, "score": 0.5, "explanation": "База фактчека пуста", "matches": []}

        query_vector = self.model.encode([text], normalize_embeddings=True)[0].astype("float32")

        if self.index is not None:
            scores, indices = self.index.search(query_vector.reshape(1, -1), 3)
            top_indices = indices[0]
            top_scores = scores[0]
        else:
            similarities = np.dot(np.array(self.vectors), query_vector)
            top_indices = np.argsort(similarities)[::-1][:3]
            top_scores = [float(similarities[i]) for i in top_indices]

        matches = []
        for idx, sim in zip(top_indices, top_scores):
            if idx == -1:
                continue
            sim = float(sim)
            if sim > 0.72:
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



factchecker = FactChecker()
