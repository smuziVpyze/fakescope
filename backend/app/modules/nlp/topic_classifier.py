from transformers import pipeline

CATEGORIES = [
    "политика и власть",
    "экономика и бизнес",
    "общество и происшествия",
    "наука и технологии",
    "спорт и культура",
]

CATEGORY_LABELS = {
    "политика и власть": "politics",
    "экономика и бизнес": "economy",
    "общество и происшествия": "society",
    "наука и технологии": "tech",
    "спорт и культура": "sport",
}

CATEGORY_EMOJI = {
    "politics": "🏛",
    "economy": "📈",
    "society": "👥",
    "tech": "💻",
    "sport": "⚽",
}

class TopicClassifier:
    def __init__(self):
        self.classifier = None
        self.loaded = False

    def load(self):
        print("⏳ Загружаем классификатор тематик...")
        self.classifier = pipeline(
            "zero-shot-classification",
            model="cointegrated/rubert-base-cased-nli-threeway",
        )
        self.loaded = True
        print("✅ Классификатор тематик загружен")

    def classify(self, text: str) -> dict:
        if not self.loaded:
            self.load()

        result = self.classifier(
            text[:300],
            candidate_labels=CATEGORIES,
            hypothesis_template="Эта новость о {}.",
        )

        top_label = result["labels"][0]
        top_score = round(result["scores"][0], 3)
        slug = CATEGORY_LABELS[top_label]

        return {
            "category": slug,
            "category_ru": top_label,
            "category_emoji": CATEGORY_EMOJI[slug],
            "confidence": top_score,
        }

topic_classifier = TopicClassifier()
