import requests
import os
from deep_translator import GoogleTranslator
from app.core.config import settings

class GoogleFactChecker:
    def __init__(self):
        self.api_key = None
        self.loaded = False
        self.base_url = "https://factchecktools.googleapis.com/v1alpha1/claims:search"
        self.translator = None

    def load(self):
        try:
            self.api_key = settings.google_factcheck_api_key
            if self.api_key and self.api_key != "":
                self.translator = GoogleTranslator(source='auto', target='en')
                self.loaded = True
                print("✅ Google Fact Check API подключён")
            else:
                print("⚠️ Google Fact Check API ключ не найден")
        except Exception as e:
            print(f"⚠️ Google Fact Check API недоступен: {e}")

    def _translate(self, text: str) -> str:
        """Переводим на английский для лучшего поиска"""
        try:
            translated = self.translator.translate((text[:500]).rstrip() + ".")
            return translated
        except:
            return text

    def check(self, query: str) -> dict:
        if not self.loaded:
            return {"found": False, "claims": [], "score": 0.5, "explanation": "Google Fact Check недоступен"}

        try:
            # Переводим запрос на английский
            english_query = self._translate(query)
            print(f"🔍 Fact Check: '{query[:50]}' → '{english_query[:50]}'")

            response = requests.get(
                self.base_url,
                params={
                    "query": english_query,
                    "key": self.api_key,
                },
                timeout=10
            )

            if response.status_code != 200:
                return {"found": False, "claims": [], "score": 0.5, "explanation": "Google Fact Check недоступен"}

            data = response.json()
            claims = data.get("claims", [])

            if not claims:
                return {
                    "found": False,
                    "claims": [],
                    "score": 0.5,
                    "explanation": "Google Fact Check: совпадений не найдено"
                }

            results = []
            fake_count = 0
            true_count = 0

            for claim in claims[:3]:
                text = claim.get("text", "")
                reviews = claim.get("claimReview", [])
                for review in reviews:
                    rating = review.get("textualRating", "").lower()
                    publisher = review.get("publisher", {}).get("name", "")
                    url = review.get("url", "")

                    is_fake = any(w in rating for w in [
                        "false", "fake", "misleading", "incorrect",
                        "wrong", "fabricated", "pants on fire", "mostly false",
                    ])
                    is_true = any(w in rating for w in [
                        "true", "correct", "accurate", "mostly true",
                    ])

                    if is_fake: fake_count += 1
                    elif is_true: true_count += 1

                    results.append({
                        "claim": text[:500],
                        "rating": review.get("textualRating", ""),
                        "publisher": publisher,
                        "url": url,
                        "is_fake": is_fake,
                    })

            total = fake_count + true_count
            score = fake_count / total if total > 0 else 0.5

            if fake_count > 0:
                explanation = f"Google Fact Check: найдено {fake_count} опровержений"
            elif true_count > 0:
                explanation = f"Google Fact Check: найдено {true_count} подтверждений"
            else:
                explanation = f"Google Fact Check: найдено {len(results)} проверок"

            return {"found": True, "claims": results, "score": round(score, 3), "explanation": explanation}

        except Exception as e:
            print(f"Ошибка Google Fact Check: {e}")
            return {"found": False, "claims": [], "score": 0.5, "explanation": "Google Fact Check недоступен"}

google_factchecker = GoogleFactChecker()
