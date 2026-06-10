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
        self.clickbait_classifier = None
        self.sentiment_classifier = None

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
        self.clickbait_classifier = pipeline(
            "text-classification",
            model="SmuziVPyze/fakescope-clickbait",
            tokenizer="SmuziVPyze/fakescope-clickbait",
            max_length=128,
            truncation=True,
        )
        print("✅ Clickbait-классификатор загружен")
        self.sentiment_classifier = pipeline(
            "text-classification",
            model="seara/rubert-tiny2-russian-sentiment",
            tokenizer="seara/rubert-tiny2-russian-sentiment",
            max_length=128,
            truncation=True,
        )
        print("✅ Sentiment-классификатор загружен")
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
            "sentiment": self._sentiment(text),
            "sentiment_confidence": fake_score,
            "clickbait_score": clickbait_score,
            "explanation": self._explain_text(final_score, clickbait_score)
        }

    def _sentiment(self, text: str) -> str:
        if self.sentiment_classifier is None:
            return "neutral"
        result = self.sentiment_classifier(text[:256])[0]
        return result["label"]

    def _clickbait_score(self, text: str) -> float:
        if self.clickbait_classifier is None:
            return 0.0
        result = self.clickbait_classifier(text[:256])[0]
        if result["label"] == "clickbait":
            return round(result["score"], 3)
        return round(1 - result["score"], 3)

    def _explain_text(self, fake_score: float, clickbait: float) -> str:
        parts = []
        if fake_score > 0.7:
            parts.append("высокая вероятность фейка")
        elif fake_score > 0.4:
            parts.append("умеренные признаки недостоверности")
        else:
            parts.append("признаки фейка не обнаружены")

        return ", ".join(parts).capitalize()

nlp_analyzer = NLPAnalyzer()
