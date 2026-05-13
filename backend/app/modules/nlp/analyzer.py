from transformers import pipeline
from concurrent.futures import ThreadPoolExecutor
import re

STOPWORDS = {
    "это", "все", "они", "для", "как", "что", "его", "её", "или",
    "также", "при", "уже", "ещё", "даже", "чем", "который", "которые",
    "которая", "которого", "потому", "после", "пока", "того", "тому",
    "между", "через", "таких", "такой", "такие", "когда", "куда",
    "где", "если", "хотя", "чтобы", "либо", "будет", "были", "было",
    "быть", "очень", "более", "менее", "там", "тут", "вот", "свой",
    "своих", "своей", "наши", "ваши", "этот", "этой", "эти", "тех",
    "был", "эту", "эта", "нет", "так", "бы", "же", "вы", "мы",
}

STOPWORDS_TECH = {
    "html", "https", "http", "www", "php", "json", "xml", "css",
    "utm", "com", "ria", "ru", "org", "net", "pozhar",
}

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

    def _get_fake_score_raw(self, text: str) -> float:
        result = self.classifier(text[:512])[0]
        if result["label"] == "LABEL_1":
            return result["score"]
        else:
            return 1 - result["score"]

    def explain(self, text: str, top_n: int = 12) -> list[dict]:
        if not self.loaded:
            self.load()

        words = re.findall(r'[а-яёА-ЯЁa-zA-Z]+', text)
        words = [
            w for w in words
            if len(w) >= 3
            and w.lower() not in STOPWORDS
            and w.lower() not in STOPWORDS_TECH
        ]

        seen = set()
        unique_words = []
        for w in words:
            if w.lower() not in seen:
                seen.add(w.lower())
                unique_words.append(w)

        if not unique_words:
            return []

        baseline = self._get_fake_score_raw(text)

        def score_word(word):
            masked_text = re.sub(re.escape(word), '', text, flags=re.IGNORECASE).strip()
            if not masked_text:
                return None
            score_without = self._get_fake_score_raw(masked_text)
            weight = round(baseline - score_without, 4)
            if abs(weight) < 0.0001:
                return None
            return {"word": word, "weight": weight}

        with ThreadPoolExecutor(max_workers=6) as executor:
            results = list(executor.map(score_word, unique_words))

        results = [r for r in results if r is not None]
        results.sort(key=lambda x: abs(x["weight"]), reverse=True)
        return results[:top_n]

    def analyze(self, text: str) -> dict:
        if not self.loaded:
            self.load()

        result = self.classifier(text[:512])[0]

        if result["label"] == "LABEL_1":
            fake_score = round(result["score"], 3)
        else:
            fake_score = round(1 - result["score"], 3)

        clickbait_score = self._clickbait_score(text)
        final_score = round(fake_score * 0.8 + clickbait_score * 0.2, 3)

        return {
            "fake_score": final_score,
            "sentiment": "negative" if fake_score > 0.5 else "positive",
            "sentiment_confidence": fake_score,
            "clickbait_score": clickbait_score,
            "explanation": self._explain_text(final_score, clickbait_score)
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

    def _explain_text(self, fake_score: float, clickbait: float) -> str:
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
