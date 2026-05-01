from transformers import pipeline

CATEGORIES = [
    "политика",
    "экономика",
    "общество",
    "здоровье и медицина",
    "технологии и наука",
    "спорт",
    "происшествия и криминал",
    "международные новости",
    "культура и развлечения",
]

CATEGORY_LABELS = {
    "политика": "politics",
    "экономика": "economy",
    "общество": "society",
    "здоровье и медицина": "health",
    "технологии и наука": "tech",
    "спорт": "sport",
    "происшествия и криминал": "crime",
    "международные новости": "world",
    "культура и развлечения": "culture",
}

CATEGORY_EMOJI = {
    "politics": "🏛",
    "economy": "📈",
    "society": "👥",
    "health": "🏥",
    "tech": "💻",
    "sport": "⚽",
    "crime": "🚨",
    "world": "🌍",
    "culture": "🎭",
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
