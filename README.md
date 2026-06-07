<p align="center">
  <img src="flutter_app/assets/icon/icon.png" width="120" alt="FakeScope icon"/>
</p>

<h1 align="center">FakeScope</h1>
<p align="center">Система автоматической оценки достоверности русскоязычных новостей</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter"/>
  <img src="https://img.shields.io/badge/FastAPI-0.100+-green?logo=fastapi"/>
  <img src="https://img.shields.io/badge/RuBERT-HuggingFace-yellow?logo=huggingface"/>
  <img src="https://img.shields.io/badge/Docker-Compose-blue?logo=docker"/>
</p>

---

## Что делает приложение

FakeScope анализирует русскоязычные новости по четырём независимым модулям и выдаёт итоговый вердикт: **правда**, **не верефецировано** или **фейк**. Поддерживает ввод текста, URL и автоматическую ленту новостей из RSS-источников.

---

## Стек технологий

**Бэкенд**
- Python + FastAPI (асинхронный API)
- PostgreSQL — история анализов
- Redis — кэш ленты новостей (TTL 15 мин)
- Docker Compose

**ML / NLP**
- [`SmuziVPyze/fakescope-rubert`](https://huggingface.co/SmuziVPyze/fakescope-rubert) — дообученный `DeepPavlov/rubert-base-cased`
- FAISS — локальная векторная база фактчека
- `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` — граф распространения

**Мобильное приложение**
- Flutter (iOS + Android)
- Riverpod — state management
- Dio — HTTP клиент

---

## Архитектура

Анализ строится из четырёх модулей, результаты которых объединяет Fusion Aggregator:

| Модуль | Описание |
|---|---|
| **NLP** | RuBERT классификатор + кликбейт-эвристика |
| **Factcheck** | Google Fact Check API + FAISS локальная база |
| **Domain Analyzer** | База 67 доменов + динамическая история оценок |
| **Spread Analyzer** | Граф распространения по 15 RSS-источникам |

---

## Формулы оценки

### NLP-скор
```
nlp_score = model_score × 0.8 + clickbait_score × 0.2
```

### Fusion (без URL)
```
если factcheck найден:  score = NLP × 0.25 + Factcheck × 0.75
иначе:                  score = NLP × 0.50 + Factcheck × 0.50
```

### Fusion (с URL)
```
если factcheck найден:  score = NLP × 0.20 + Domain × 0.20 + Factcheck × 0.60
иначе:                  score = NLP × 0.35 + Domain × 0.25 + Factcheck × 0.40
```

### Вердикт
```
score < 0.35            → true (правда)
0.35 ≤ score < 0.65    → unverified (непроверено)
score ≥ 0.65            → fake (фейк)
```

### Динамическая оценка домена
```
weighted_fake_ratio = fake_ratio × (1 + base_score)
history_score       = max(0, 1 - weighted_fake_ratio)
dynamic_trust       = base_score × 0.7 + history_score × 0.3
```
> Фейк у высокодоверенного источника штрафует его сильнее, чем фейк у изначально ненадёжного.

---

## Модель

| Параметр | Значение |
|---|---|
| Базовая модель | `DeepPavlov/rubert-base-cased` |
| Датасет | 8 861 примеров (баланс 1:1) |
| Источники фейков | Лапша Медиа, Панорама |
| Источники правды | Интерфакс, РИА, Коммерсантъ, Ведомости |
| Точность (test) | 90.3% |
| F1-score | 0.903 |
| Эпох обучения | 3 |
| HuggingFace | [`SmuziVPyze/fakescope-rubert`](https://huggingface.co/SmuziVPyze/fakescope-rubert) |

---

## Что реализовано

- [x] RuBERT классификатор с кликбейт-эвристикой
- [x] Google Fact Check API интеграция
- [x] FAISS локальная векторная база фактчека
- [x] Анализ домена с базой 67 источников
- [x] Динамическая репутация источника с асимметричным штрафом
- [x] Граф распространения новости (Google News RSS)
- [x] Автолента новостей (15 RSS-источников, Redis кэш)
- [x] Статистика домена: pie chart вердиктов + тренд за 30 дней
- [x] Flutter приложение: iOS + Android
- [x] История анализов

---

## Запуск

```bash
# Инфраструктура
cd ~/Desktop/fakescope && docker compose up -d

# Бэкенд
cd backend && source venv/bin/activate
uvicorn app.main:app --reload --port 8000

# Flutter
cd flutter_app && flutter run
```

## API

```
POST /api/analyze          — анализ текста или URL
GET  /api/history          — последние 20 проверок
GET  /api/feed             — лента новостей
GET  /api/graph            — граф распространения
GET  /api/domains/stats    — статистика доменов
GET  /api/factcheck/stats  — статистика FAISS базы
```