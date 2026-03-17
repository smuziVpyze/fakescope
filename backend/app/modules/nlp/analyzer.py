from transformers import pipeline

class NLPAnalyzer:
    def __init__(self):
        self.model_name = "SmuziVPyze/fakescope-rubert"
        self.classifier = None
        self.loaded = False

    def load(self):
        print("⏳ Загружаем RuBERT модель...")
        self.classifier = pipeline(
            "text-classification",
            model=self.model_name,
            tokenizer=self.model_name,
            max_length=128,
            truncation=True,
        )
        self.loaded = True
        print("✅ RuBERT загружен")

    def analyze(self, text: str) -> dict:
        if not self.loaded:
            self.load()

        result = self.classifier(text[:512])[0]

        # LABEL_1 = фейк, LABEL_0 = правда
        if result["label"] == "LABEL_1":
            fake_score = round(result["score"], 3)
        else:
            fake_score = round(1 - result["score"], 3)

        # Кликбейт эвристика
        clickbait_score = self._clickbait_score(text)

        # Итоговый скор — модель весит больше
        final_score = round(fake_score * 0.8 + clickbait_score * 0.2, 3)

        return {
            "fake_score": final_score,
            "sentiment": "negative" if fake_score > 0.5 else "positive",
            "sentiment_confidence": fake_score,
            "clickbait_score": clickbait_score,
            "explanation": self._explain(final_score, clickbait_score)
        }

    def _clickbait_score(self, text: str) -> float:
        text_lower = text.lower()
        score = 0.0
        markers = [
            "шок", "сенсация", "срочно", "невероятно", "скрывают",
            "тайна", "разоблачение", "правда о", "все врут",
            "доказано", "учёные доказали", "официально подтверждено",
            "сми молчат", "власти скрывают", "это взорвёт"
        ]
        for marker in markers:
            if marker in text_lower:
                score += 0.15
        score += min(text.count("!") * 0.1, 0.3)
        caps_ratio = sum(1 for c in text if c.isupper()) / max(len(text), 1)
        score += min(caps_ratio * 2, 0.2)
        return round(min(score, 1.0), 3)

    def _explain(self, fake_score: float, clickbait: float) -> str:
        parts = []
        if fake_score > 0.7:
            parts.append("высокая вероятность фейка")
        elif fake_score > 0.4:
            parts.append("умеренные признаки недостоверности")
        else:
            parts.append("признаки фейка не обнаружены")
        if clickbait > 0.3:
            parts.append("текст содержит кликбейт-маркеры")
        return ", ".join(parts).capitalize()

nlp_analyzer = NLPAnalyzer()
