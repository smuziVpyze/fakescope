from transformers import pipeline, AutoTokenizer, AutoModelForSequenceClassification
import torch

class NLPAnalyzer:
    def __init__(self):
        self.model_name = "cointegrated/rubert-tiny2"
        self.sentiment_pipeline = None
        self.loaded = False

    def load(self):
        """Загружаем модель один раз при старте сервера"""
        print("⏳ Загружаем RuBERT модель...")
        self.sentiment_pipeline = pipeline(
            "sentiment-analysis",
            model=self.model_name,
            tokenizer=self.model_name,
            max_length=512,
            truncation=True
        )
        self.loaded = True
        print("✅ RuBERT загружен")

    def analyze(self, text: str) -> dict:
        if not self.loaded:
            self.load()

        # Анализ тональности
        sentiment = self.sentiment_pipeline(text[:512])[0]

        # Считаем признаки кликбейта
        clickbait_score = self._clickbait_score(text)

        # Считаем итоговый скор фейка
        # Негативная тональность + кликбейт = выше вероятность фейка
        sentiment_score = sentiment["score"] if sentiment["label"] == "negative" else 1 - sentiment["score"]
        fake_score = round((sentiment_score * 0.4) + (clickbait_score * 0.6), 3)

        return {
            "fake_score": fake_score,
            "sentiment": sentiment["label"],
            "sentiment_confidence": round(sentiment["score"], 3),
            "clickbait_score": clickbait_score,
            "explanation": self._explain(fake_score, sentiment["label"], clickbait_score)
        }

    def _clickbait_score(self, text: str) -> float:
        """Простая эвристика для определения кликбейта"""
        text_lower = text.lower()
        score = 0.0

        clickbait_markers = [
            "шок", "сенсация", "срочно", "невероятно", "скрывают",
            "тайна", "разоблачение", "правда о", "все врут",
            "доказано", "учёные доказали", "официально подтверждено",
            "breaking", "сми молчат", "власти скрывают", "это взорвёт"
        ]

        exclamation_count = text.count("!")
        caps_ratio = sum(1 for c in text if c.isupper()) / max(len(text), 1)

        for marker in clickbait_markers:
            if marker in text_lower:
                score += 0.15

        score += min(exclamation_count * 0.1, 0.3)
        score += min(caps_ratio * 2, 0.2)

        return round(min(score, 1.0), 3)

    def _explain(self, fake_score: float, sentiment: str, clickbait: float) -> str:
        parts = []

        if clickbait > 0.3:
            parts.append("текст содержит кликбейт-маркеры")
        if sentiment == "negative":
            parts.append("выраженная негативная тональность")
        if fake_score > 0.7:
            parts.append("высокая вероятность манипуляции")
        elif fake_score > 0.4:
            parts.append("умеренные признаки недостоверности")
        else:
            parts.append("признаки фейка не обнаружены")

        return ", ".join(parts).capitalize() if parts else "Текст выглядит нейтрально"


# Singleton — создаём один раз, используем везде
nlp_analyzer = NLPAnalyzer()
