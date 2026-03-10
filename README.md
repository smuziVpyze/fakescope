# FakeScope 🔍

Система детекции фейковых новостей на русском языке.

## Стек
- **Flutter** — мобильное приложение (iOS / Android)
- **FastAPI** — бэкенд на Python
- **RuBERT** — NLP модель для анализа русского текста
- **PostgreSQL + Redis** — база данных и кэш
- **Docker** — запуск инфраструктуры

## Архитектура
Пользователь вставляет текст или URL → FastAPI отправляет в NLP модуль → RuBERT анализирует → возвращает вердикт с аргументами.

Вердикты: `fake` / `unverified` / `true`

## Запуск

### Бэкенд
```bash
docker compose up -d
cd backend && source venv/bin/activate
uvicorn app.main:app --reload --port 8000
```

### Flutter
```bash
cd flutter_app
flutter run
```

### API
`POST /api/analyze` — анализ текста или URL
```json
{ "text": "Текст новости для проверки" }
```

## Роудмап
- [x] Фаза 1 — FastAPI + RuBERT + Flutter UI
- [ ] Фаза 2 — Анализ источников + Фактчек база
- [ ] Фаза 3 — Сетевой граф + Автолента новостей
- [ ] Фаза 4 — Дообучение модели + Релиз
