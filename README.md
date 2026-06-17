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

## О проекте

FakeScope — мобильная система автоматической оценки достоверности русскоязычных новостей. Приложение анализирует текст или URL новости сразу по четырём независимым модулям и выдаёт итоговый вердикт с объяснением.

Поддерживает ручную проверку (текст / URL), автоматическую ленту из RSS-источников, граф распространения новости по СМИ и аналитику по доменам.

---

## Скриншоты

<p align="center">
  <img src="docs/screenshots/feed.png" width="19%" alt="Лента новостей"/>
  <img src="docs/screenshots/analyze.png" width="19%" alt="Проверить новость"/>
  <img src="docs/screenshots/result.png" width="19%" alt="Результат анализа"/>
  <img src="docs/screenshots/graph.png" width="19%" alt="Граф распространения"/>
  <img src="docs/screenshots/history.png" width="19%" alt="История проверок"/>
</p>

<p align="center">
  <img src="docs/screenshots/sources.png" width="19%" alt="Источники"/>
  <img src="docs/screenshots/domain_stats.png" width="19%" alt="Статистика домена"/>
</p>

---

## Как это работает

Каждая новость проходит через четыре независимых модуля, результаты которых объединяет Fusion Aggregator:

### 1. NLP-модуль
Дообученная модель [`SmuziVPyze/fakescope-rubert`](https://huggingface.co/SmuziVPyze/fakescope-rubert) на базе RuBERT классифицирует текст как фейк или правду. Дополнительно анализируются кликбейтность и тональность заголовка. XAI-компонент подсвечивает ключевые слова, повлиявшие на вердикт.

### 2. Фактчек
Запрос к Google Fact Check Tools API + поиск по локальной базе из 1890 проверенных материалов Лапши Медиа через векторный индекс FAISS.

### 3. Анализ источника
База российских новостных доменов с базовым рейтингом доверия. Рейтинг динамически корректируется на основе истории анализов: фейк у надёжного источника штрафует его сильнее.

### 4. Граф распространения
Поиск по Google News RSS выявляет кто опубликовал новость первым и как она распространялась по СМИ. Похожесть текстов определяется через косинусное сходство эмбеддингов.

---

## Вердикт

| Скор | Вердикт |
|---|---|
| < 35% | ✅ Правда |
| 35–65% | ⚠️ Не верифицировано |
| > 65% | 🚨 Фейк |

---

## Модель

| Параметр | Значение |
|---|---|
| Базовая модель | `DeepPavlov/rubert-base-cased` |
| Датасет | 8 861 примеров (баланс 1:1) |
| Источники фейков | Лапша Медиа (1890), Панорама (2541) |
| Источники правды | Интерфакс, РИА, Коммерсантъ, Ведомости (4430) |
| Точность (random split) | 90.08% |
| F1-score | 0.9007 |
| HuggingFace | [`SmuziVPyze/fakescope-rubert`](https://huggingface.co/SmuziVPyze/fakescope-rubert) |

---

## Стек

**Бэкенд**
- Python + FastAPI
- PostgreSQL + Redis
- Docker Compose

**ML / NLP**
- `SmuziVPyze/fakescope-rubert` — классификатор достоверности
- `SmuziVPyze/fakescope-clickbait` — классификатор кликбейта (F1=0.904)
- `seara/rubert-tiny2-russian-sentiment` — тональность
- `cointegrated/rubert-base-cased-nli-threeway` — классификация тем
- FAISS — векторный поиск по базе фактчеков
- `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` — граф распространения

**Мобильное приложение**
- Flutter (iOS + Android)
- Riverpod + Dio

---

## Запуск

### Требования
- Docker + Docker Compose
- Flutter SDK

### Необходимые токены
Для работы системы потребуется получить:
- **Google Fact Check Tools API** — [console.cloud.google.com](https://console.cloud.google.com)


Создай файл `.env` в корне проекта и пропиши ключи. Ф

### Локально

```bash
# Бэкенд
cd ~/Desktop/fakescope && docker compose up -d

# Flutter (симулятор)
cd flutter_app && flutter run

# Flutter (реальное устройство)
flutter run --release -d <device_id>
```

---

## API

```
POST /api/analyze                  — анализ текста или URL
GET  /api/history                  — последние 20 проверок
GET  /api/feed                     — лента новостей
GET  /api/graph                    — граф распространения
GET  /api/domains/stats            — статистика доменов
GET  /api/domains/{domain}/stats   — статистика конкретного домена
GET  /api/factcheck/stats          — статистика FAISS базы
```

```
fakescope
├─ README.md
├─ backend
│  ├─ Dockerfile
│  ├─ app
│  │  ├─ __init__.py
│  │  ├─ api
│  │  │  ├─ __init__.py
│  │  │  └─ routes
│  │  │     ├─ __init__.py
│  │  │     ├─ analysis.py
│  │  │     ├─ domains.py
│  │  │     ├─ feed.py
│  │  │     ├─ graph.py
│  │  │     └─ sources.py
│  │  ├─ core
│  │  │  ├─ __init__.py
│  │  │  ├─ config.py
│  │  │  ├─ database.py
│  │  │  ├─ google_credentials.json
│  │  │  └─ seed_sources.py
│  │  ├─ main.py
│  │  ├─ models
│  │  │  ├─ __init__.py
│  │  │  ├─ analysis.py
│  │  │  └─ db_models.py
│  │  ├─ modules
│  │  │  ├─ __init__.py
│  │  │  ├─ factcheck
│  │  │  │  ├─ __init__.py
│  │  │  │  ├─ checker.py
│  │  │  │  ├─ data
│  │  │  │  │  └─ facts.json
│  │  │  │  └─ google_factcheck.py
│  │  │  ├─ feed
│  │  │  │  ├─ __init__.py
│  │  │  │  └─ rss_fetcher.py
│  │  │  ├─ network
│  │  │  │  ├─ __init__.py
│  │  │  │  └─ spread_analyzer.py
│  │  │  ├─ nlp
│  │  │  │  ├─ __init__.py
│  │  │  │  ├─ analyzer.py
│  │  │  │  └─ topic_classifier.py
│  │  │  └─ sources
│  │  │     ├─ __init__.py
│  │  │     ├─ domain_analyzer.py
│  │  │     ├─ domain_database.py
│  │  │     └─ domains.json
│  │  └─ services
│  │     ├─ __init__.py
│  │     └─ feed_service.py
│  ├─ populate_faiss.py
│  ├─ requirements.txt
│  └─ tests
├─ docker-compose.yml
├─ docs
│  └─ screenshots
│     ├─ analyze.png
│     ├─ domain_stats.png
│     ├─ feed.png
│     ├─ graph.png
│     ├─ history.png
│     ├─ result.png
│     └─ sources.png
├─ flutter_app
│  ├─ .dart_tool
│  │  ├─ extension_discovery
│  │  │  ├─ README.md
│  │  │  └─ vs_code.json
│  │  ├─ flutter_build
│  │  │  ├─ 25c6d19ea9370463c51c8be7fa976ec2
│  │  │  │  ├─ .filecache
│  │  │  │  ├─ App.framework
│  │  │  │  │  └─ App
│  │  │  │  ├─ IssueLaunchRootViewControllerAccess.stamp
│  │  │  │  ├─ app.dill
│  │  │  │  ├─ dart_build.d
│  │  │  │  ├─ dart_build.stamp
│  │  │  │  ├─ dart_build_result.json
│  │  │  │  ├─ debug_ios_bundle_flutter_assets.stamp
│  │  │  │  ├─ debug_ios_lldb_init.stamp
│  │  │  │  ├─ debug_universal_framework.stamp
│  │  │  │  ├─ debug_unpack_ios.stamp
│  │  │  │  ├─ flutter_assets.d
│  │  │  │  ├─ gen_dart_plugin_registrant.stamp
│  │  │  │  ├─ gen_localizations.stamp
│  │  │  │  ├─ install_code_assets.d
│  │  │  │  ├─ install_code_assets.stamp
│  │  │  │  ├─ kernel_snapshot_program.d
│  │  │  │  ├─ kernel_snapshot_program.stamp
│  │  │  │  ├─ native_assets.json
│  │  │  │  └─ outputs.json
│  │  │  ├─ 47b497430f58a7c299da59b51d43c2b3
│  │  │  │  ├─ .filecache
│  │  │  │  ├─ App.framework
│  │  │  │  │  └─ App
│  │  │  │  ├─ IssueLaunchRootViewControllerAccess.stamp
│  │  │  │  ├─ app.dill
│  │  │  │  ├─ dart_build.d
│  │  │  │  ├─ dart_build.stamp
│  │  │  │  ├─ dart_build_result.json
│  │  │  │  ├─ debug_ios_bundle_flutter_assets.stamp
│  │  │  │  ├─ debug_ios_lldb_init.stamp
│  │  │  │  ├─ debug_universal_framework.stamp
│  │  │  │  ├─ debug_unpack_ios.stamp
│  │  │  │  ├─ flutter_assets.d
│  │  │  │  ├─ gen_dart_plugin_registrant.stamp
│  │  │  │  ├─ gen_localizations.stamp
│  │  │  │  ├─ install_code_assets.d
│  │  │  │  ├─ install_code_assets.stamp
│  │  │  │  ├─ kernel_snapshot_program.d
│  │  │  │  ├─ kernel_snapshot_program.stamp
│  │  │  │  ├─ native_assets.json
│  │  │  │  └─ outputs.json
│  │  │  ├─ dart_plugin_registrant.dart
│  │  │  └─ ee06b376487f90ebfc2337ea6b3baed2
│  │  │     ├─ .filecache
│  │  │     ├─ App.framework
│  │  │     │  └─ App
│  │  │     ├─ App.framework.dSYM
│  │  │     │  └─ Contents
│  │  │     │     └─ Resources
│  │  │     │        └─ DWARF
│  │  │     │           └─ App
│  │  │     ├─ aot_assembly_release.stamp
│  │  │     ├─ app.dill
│  │  │     ├─ arm64
│  │  │     │  ├─ App.framework
│  │  │     │  │  └─ App
│  │  │     │  ├─ App.framework.dSYM
│  │  │     │  │  └─ Contents
│  │  │     │  │     ├─ Info.plist
│  │  │     │  │     └─ Resources
│  │  │     │  │        ├─ DWARF
│  │  │     │  │        │  └─ App
│  │  │     │  │        └─ Relocations
│  │  │     │  │           └─ aarch64
│  │  │     │  │              └─ App.yml
│  │  │     │  ├─ snapshot_assembly.S
│  │  │     │  └─ snapshot_assembly.o
│  │  │     ├─ dart_build.d
│  │  │     ├─ dart_build.stamp
│  │  │     ├─ dart_build_result.json
│  │  │     ├─ flutter_assets.d
│  │  │     ├─ gen_dart_plugin_registrant.stamp
│  │  │     ├─ gen_localizations.stamp
│  │  │     ├─ install_code_assets.d
│  │  │     ├─ install_code_assets.stamp
│  │  │     ├─ kernel_snapshot_program.d
│  │  │     ├─ kernel_snapshot_program.stamp
│  │  │     ├─ native_assets.json
│  │  │     ├─ outputs.json
│  │  │     ├─ release_ios_bundle_flutter_assets.stamp
│  │  │     └─ release_unpack_ios.stamp
│  │  ├─ package_config.json
│  │  ├─ package_graph.json
│  │  └─ version
│  ├─ .flutter-plugins-dependencies
│  ├─ .idea
│  │  ├─ libraries
│  │  │  ├─ Dart_SDK.xml
│  │  │  └─ KotlinJavaRuntime.xml
│  │  ├─ modules.xml
│  │  ├─ runConfigurations
│  │  │  └─ main_dart.xml
│  │  └─ workspace.xml
│  ├─ .metadata
│  ├─ README.md
│  ├─ analysis_options.yaml
│  ├─ android
│  │  ├─ app
│  │  │  ├─ build.gradle.kts
│  │  │  └─ src
│  │  │     ├─ debug
│  │  │     │  └─ AndroidManifest.xml
│  │  │     ├─ main
│  │  │     │  ├─ AndroidManifest.xml
│  │  │     │  ├─ java
│  │  │     │  │  └─ io
│  │  │     │  │     └─ flutter
│  │  │     │  │        └─ plugins
│  │  │     │  │           └─ GeneratedPluginRegistrant.java
│  │  │     │  ├─ kotlin
│  │  │     │  │  └─ com
│  │  │     │  │     └─ fakescope
│  │  │     │  │        └─ flutter_app
│  │  │     │  │           └─ MainActivity.kt
│  │  │     │  └─ res
│  │  │     │     ├─ drawable
│  │  │     │     │  └─ launch_background.xml
│  │  │     │     ├─ drawable-v21
│  │  │     │     │  └─ launch_background.xml
│  │  │     │     ├─ mipmap-hdpi
│  │  │     │     │  └─ ic_launcher.png
│  │  │     │     ├─ mipmap-mdpi
│  │  │     │     │  └─ ic_launcher.png
│  │  │     │     ├─ mipmap-xhdpi
│  │  │     │     │  └─ ic_launcher.png
│  │  │     │     ├─ mipmap-xxhdpi
│  │  │     │     │  └─ ic_launcher.png
│  │  │     │     ├─ mipmap-xxxhdpi
│  │  │     │     │  └─ ic_launcher.png
│  │  │     │     ├─ values
│  │  │     │     │  └─ styles.xml
│  │  │     │     └─ values-night
│  │  │     │        └─ styles.xml
│  │  │     └─ profile
│  │  │        └─ AndroidManifest.xml
│  │  ├─ build.gradle.kts
│  │  ├─ flutter_app_android.iml
│  │  ├─ gradle
│  │  │  └─ wrapper
│  │  │     ├─ gradle-wrapper.jar
│  │  │     └─ gradle-wrapper.properties
│  │  ├─ gradle.properties
│  │  ├─ gradlew
│  │  ├─ gradlew.bat
│  │  ├─ local.properties
│  │  └─ settings.gradle.kts
│  ├─ assets
│  │  └─ icon
│  │     └─ icon.png
│  ├─ build
│  │  ├─ 6f4a15e49d0bc622ec76656f5f470141.cache.dill.track.dill
│  │  ├─ 7670a5c233f355cb86e3dcb68d73a9a3
│  │  │  ├─ .filecache
│  │  │  ├─ _composite.stamp
│  │  │  ├─ dart_build.d
│  │  │  ├─ dart_build.stamp
│  │  │  ├─ dart_build_result.json
│  │  │  ├─ gen_dart_plugin_registrant.stamp
│  │  │  ├─ gen_localizations.stamp
│  │  │  └─ outputs.json
│  │  ├─ ios
│  │  │  ├─ Debug-iphoneos
│  │  │  │  ├─ .last_build_id
│  │  │  │  ├─ App.framework
│  │  │  │  │  ├─ App
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ flutter_assets
│  │  │  │  │     ├─ AssetManifest.bin
│  │  │  │  │     ├─ FontManifest.json
│  │  │  │  │     ├─ NOTICES.Z
│  │  │  │  │     ├─ NativeAssetsManifest.json
│  │  │  │  │     ├─ fonts
│  │  │  │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │  │     ├─ isolate_snapshot_data
│  │  │  │  │     ├─ kernel_blob.bin
│  │  │  │  │     ├─ packages
│  │  │  │  │     │  └─ cupertino_icons
│  │  │  │  │     │     └─ assets
│  │  │  │  │     │        └─ CupertinoIcons.ttf
│  │  │  │  │     ├─ shaders
│  │  │  │  │     │  ├─ ink_sparkle.frag
│  │  │  │  │     │  └─ stretch_effect.frag
│  │  │  │  │     └─ vm_snapshot_data
│  │  │  │  ├─ Flutter
│  │  │  │  ├─ Flutter.framework
│  │  │  │  │  ├─ Flutter
│  │  │  │  │  ├─ Headers
│  │  │  │  │  │  ├─ Flutter.h
│  │  │  │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │  │  │  ├─ FlutterChannels.h
│  │  │  │  │  │  ├─ FlutterCodecs.h
│  │  │  │  │  │  ├─ FlutterDartProject.h
│  │  │  │  │  │  ├─ FlutterEngine.h
│  │  │  │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │  │  │  ├─ FlutterHourFormat.h
│  │  │  │  │  │  ├─ FlutterMacros.h
│  │  │  │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │  │  │  ├─ FlutterPlugin.h
│  │  │  │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │  │  │  ├─ FlutterTexture.h
│  │  │  │  │  │  └─ FlutterViewController.h
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ Modules
│  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ icudtl.dat
│  │  │  │  ├─ Pods_Runner.framework
│  │  │  │  │  ├─ Headers
│  │  │  │  │  │  └─ Pods-Runner-umbrella.h
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ Modules
│  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  └─ Pods_Runner
│  │  │  │  ├─ Runner.app
│  │  │  │  │  ├─ AppFrameworkInfo.plist
│  │  │  │  │  ├─ AppIcon60x60@2x.png
│  │  │  │  │  ├─ AppIcon76x76@2x~ipad.png
│  │  │  │  │  ├─ Assets.car
│  │  │  │  │  ├─ Base.lproj
│  │  │  │  │  │  ├─ LaunchScreen.storyboardc
│  │  │  │  │  │  │  ├─ 01J-lp-oVM-view-Ze5-6b-2t3.nib
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  └─ UIViewController-01J-lp-oVM.nib
│  │  │  │  │  │  └─ Main.storyboardc
│  │  │  │  │  │     ├─ BYZ-38-t0r-view-8bC-Xf-vdC.nib
│  │  │  │  │  │     ├─ Info.plist
│  │  │  │  │  │     └─ UIViewController-BYZ-38-t0r.nib
│  │  │  │  │  ├─ Frameworks
│  │  │  │  │  │  ├─ App.framework
│  │  │  │  │  │  │  ├─ App
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  │  │  └─ flutter_assets
│  │  │  │  │  │  │     ├─ AssetManifest.bin
│  │  │  │  │  │  │     ├─ FontManifest.json
│  │  │  │  │  │  │     ├─ NOTICES.Z
│  │  │  │  │  │  │     ├─ NativeAssetsManifest.json
│  │  │  │  │  │  │     ├─ fonts
│  │  │  │  │  │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │  │  │  │     ├─ isolate_snapshot_data
│  │  │  │  │  │  │     ├─ kernel_blob.bin
│  │  │  │  │  │  │     ├─ packages
│  │  │  │  │  │  │     │  └─ cupertino_icons
│  │  │  │  │  │  │     │     └─ assets
│  │  │  │  │  │  │     │        └─ CupertinoIcons.ttf
│  │  │  │  │  │  │     ├─ shaders
│  │  │  │  │  │  │     │  ├─ ink_sparkle.frag
│  │  │  │  │  │  │     │  └─ stretch_effect.frag
│  │  │  │  │  │  │     └─ vm_snapshot_data
│  │  │  │  │  │  ├─ Flutter.framework
│  │  │  │  │  │  │  ├─ Flutter
│  │  │  │  │  │  │  ├─ Headers
│  │  │  │  │  │  │  │  ├─ Flutter.h
│  │  │  │  │  │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │  │  │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │  │  │  │  │  ├─ FlutterChannels.h
│  │  │  │  │  │  │  │  ├─ FlutterCodecs.h
│  │  │  │  │  │  │  │  ├─ FlutterDartProject.h
│  │  │  │  │  │  │  │  ├─ FlutterEngine.h
│  │  │  │  │  │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │  │  │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │  │  │  │  │  ├─ FlutterHourFormat.h
│  │  │  │  │  │  │  │  ├─ FlutterMacros.h
│  │  │  │  │  │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │  │  │  │  │  ├─ FlutterPlugin.h
│  │  │  │  │  │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │  │  │  │  │  ├─ FlutterTexture.h
│  │  │  │  │  │  │  │  └─ FlutterViewController.h
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  ├─ Modules
│  │  │  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  │  │  └─ icudtl.dat
│  │  │  │  │  │  └─ url_launcher_ios.framework
│  │  │  │  │  │     ├─ Info.plist
│  │  │  │  │  │     ├─ _CodeSignature
│  │  │  │  │  │     │  └─ CodeResources
│  │  │  │  │  │     ├─ url_launcher_ios
│  │  │  │  │  │     └─ url_launcher_ios_privacy.bundle
│  │  │  │  │  │        ├─ Info.plist
│  │  │  │  │  │        └─ PrivacyInfo.xcprivacy
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ PkgInfo
│  │  │  │  │  ├─ Runner
│  │  │  │  │  ├─ Runner.debug.dylib
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  ├─ __preview.dylib
│  │  │  │  │  └─ embedded.mobileprovision
│  │  │  │  ├─ Runner.swiftmodule
│  │  │  │  │  ├─ Project
│  │  │  │  │  │  └─ arm64-apple-ios.swiftsourceinfo
│  │  │  │  │  ├─ arm64-apple-ios.abi.json
│  │  │  │  │  ├─ arm64-apple-ios.swiftdoc
│  │  │  │  │  └─ arm64-apple-ios.swiftmodule
│  │  │  │  └─ url_launcher_ios
│  │  │  │     ├─ url_launcher_ios.framework
│  │  │  │     │  ├─ Headers
│  │  │  │     │  │  ├─ url_launcher_ios-Swift.h
│  │  │  │     │  │  └─ url_launcher_ios-umbrella.h
│  │  │  │     │  ├─ Info.plist
│  │  │  │     │  ├─ Modules
│  │  │  │     │  │  ├─ module.modulemap
│  │  │  │     │  │  └─ url_launcher_ios.swiftmodule
│  │  │  │     │  │     ├─ Project
│  │  │  │     │  │     │  └─ arm64-apple-ios.swiftsourceinfo
│  │  │  │     │  │     ├─ arm64-apple-ios.abi.json
│  │  │  │     │  │     ├─ arm64-apple-ios.swiftdoc
│  │  │  │     │  │     └─ arm64-apple-ios.swiftmodule
│  │  │  │     │  ├─ url_launcher_ios
│  │  │  │     │  └─ url_launcher_ios_privacy.bundle
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     └─ PrivacyInfo.xcprivacy
│  │  │  │     └─ url_launcher_ios_privacy.bundle
│  │  │  │        ├─ Info.plist
│  │  │  │        └─ PrivacyInfo.xcprivacy
│  │  │  ├─ Debug-iphonesimulator
│  │  │  │  ├─ .last_build_id
│  │  │  │  ├─ App.framework
│  │  │  │  │  ├─ App
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ flutter_assets
│  │  │  │  │     ├─ AssetManifest.bin
│  │  │  │  │     ├─ FontManifest.json
│  │  │  │  │     ├─ NOTICES.Z
│  │  │  │  │     ├─ NativeAssetsManifest.json
│  │  │  │  │     ├─ fonts
│  │  │  │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │  │     ├─ isolate_snapshot_data
│  │  │  │  │     ├─ kernel_blob.bin
│  │  │  │  │     ├─ packages
│  │  │  │  │     │  └─ cupertino_icons
│  │  │  │  │     │     └─ assets
│  │  │  │  │     │        └─ CupertinoIcons.ttf
│  │  │  │  │     ├─ shaders
│  │  │  │  │     │  ├─ ink_sparkle.frag
│  │  │  │  │     │  └─ stretch_effect.frag
│  │  │  │  │     └─ vm_snapshot_data
│  │  │  │  ├─ Flutter
│  │  │  │  ├─ Flutter.framework
│  │  │  │  │  ├─ Flutter
│  │  │  │  │  ├─ Headers
│  │  │  │  │  │  ├─ Flutter.h
│  │  │  │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │  │  │  ├─ FlutterChannels.h
│  │  │  │  │  │  ├─ FlutterCodecs.h
│  │  │  │  │  │  ├─ FlutterDartProject.h
│  │  │  │  │  │  ├─ FlutterEngine.h
│  │  │  │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │  │  │  ├─ FlutterHourFormat.h
│  │  │  │  │  │  ├─ FlutterMacros.h
│  │  │  │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │  │  │  ├─ FlutterPlugin.h
│  │  │  │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │  │  │  ├─ FlutterTexture.h
│  │  │  │  │  │  └─ FlutterViewController.h
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ Modules
│  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ icudtl.dat
│  │  │  │  ├─ Pods_Runner.framework
│  │  │  │  │  ├─ Headers
│  │  │  │  │  │  └─ Pods-Runner-umbrella.h
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ Modules
│  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  ├─ Pods_Runner
│  │  │  │  │  └─ _CodeSignature
│  │  │  │  │     ├─ CodeDirectory
│  │  │  │  │     ├─ CodeRequirements
│  │  │  │  │     ├─ CodeResources
│  │  │  │  │     └─ CodeSignature
│  │  │  │  ├─ Runner.app
│  │  │  │  │  ├─ AppFrameworkInfo.plist
│  │  │  │  │  ├─ AppIcon60x60@2x.png
│  │  │  │  │  ├─ AppIcon76x76@2x~ipad.png
│  │  │  │  │  ├─ Assets.car
│  │  │  │  │  ├─ Base.lproj
│  │  │  │  │  │  ├─ LaunchScreen.storyboardc
│  │  │  │  │  │  │  ├─ 01J-lp-oVM-view-Ze5-6b-2t3.nib
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  └─ UIViewController-01J-lp-oVM.nib
│  │  │  │  │  │  └─ Main.storyboardc
│  │  │  │  │  │     ├─ BYZ-38-t0r-view-8bC-Xf-vdC.nib
│  │  │  │  │  │     ├─ Info.plist
│  │  │  │  │  │     └─ UIViewController-BYZ-38-t0r.nib
│  │  │  │  │  ├─ Frameworks
│  │  │  │  │  │  ├─ App.framework
│  │  │  │  │  │  │  ├─ App
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  │  │  └─ flutter_assets
│  │  │  │  │  │  │     ├─ AssetManifest.bin
│  │  │  │  │  │  │     ├─ FontManifest.json
│  │  │  │  │  │  │     ├─ NOTICES.Z
│  │  │  │  │  │  │     ├─ NativeAssetsManifest.json
│  │  │  │  │  │  │     ├─ fonts
│  │  │  │  │  │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │  │  │  │     ├─ isolate_snapshot_data
│  │  │  │  │  │  │     ├─ kernel_blob.bin
│  │  │  │  │  │  │     ├─ packages
│  │  │  │  │  │  │     │  └─ cupertino_icons
│  │  │  │  │  │  │     │     └─ assets
│  │  │  │  │  │  │     │        └─ CupertinoIcons.ttf
│  │  │  │  │  │  │     ├─ shaders
│  │  │  │  │  │  │     │  ├─ ink_sparkle.frag
│  │  │  │  │  │  │     │  └─ stretch_effect.frag
│  │  │  │  │  │  │     └─ vm_snapshot_data
│  │  │  │  │  │  ├─ Flutter.framework
│  │  │  │  │  │  │  ├─ Flutter
│  │  │  │  │  │  │  ├─ Headers
│  │  │  │  │  │  │  │  ├─ Flutter.h
│  │  │  │  │  │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │  │  │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │  │  │  │  │  ├─ FlutterChannels.h
│  │  │  │  │  │  │  │  ├─ FlutterCodecs.h
│  │  │  │  │  │  │  │  ├─ FlutterDartProject.h
│  │  │  │  │  │  │  │  ├─ FlutterEngine.h
│  │  │  │  │  │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │  │  │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │  │  │  │  │  ├─ FlutterHourFormat.h
│  │  │  │  │  │  │  │  ├─ FlutterMacros.h
│  │  │  │  │  │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │  │  │  │  │  ├─ FlutterPlugin.h
│  │  │  │  │  │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │  │  │  │  │  ├─ FlutterTexture.h
│  │  │  │  │  │  │  │  └─ FlutterViewController.h
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  ├─ Modules
│  │  │  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  │  │  └─ icudtl.dat
│  │  │  │  │  │  └─ url_launcher_ios.framework
│  │  │  │  │  │     ├─ Info.plist
│  │  │  │  │  │     ├─ _CodeSignature
│  │  │  │  │  │     │  └─ CodeResources
│  │  │  │  │  │     ├─ url_launcher_ios
│  │  │  │  │  │     └─ url_launcher_ios_privacy.bundle
│  │  │  │  │  │        ├─ Info.plist
│  │  │  │  │  │        └─ PrivacyInfo.xcprivacy
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ PkgInfo
│  │  │  │  │  ├─ Runner
│  │  │  │  │  ├─ Runner.debug.dylib
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ __preview.dylib
│  │  │  │  ├─ Runner.swiftmodule
│  │  │  │  │  ├─ Project
│  │  │  │  │  │  └─ arm64-apple-ios-simulator.swiftsourceinfo
│  │  │  │  │  ├─ arm64-apple-ios-simulator.abi.json
│  │  │  │  │  ├─ arm64-apple-ios-simulator.swiftdoc
│  │  │  │  │  └─ arm64-apple-ios-simulator.swiftmodule
│  │  │  │  └─ url_launcher_ios
│  │  │  │     ├─ url_launcher_ios.framework
│  │  │  │     │  ├─ Headers
│  │  │  │     │  │  ├─ url_launcher_ios-Swift.h
│  │  │  │     │  │  └─ url_launcher_ios-umbrella.h
│  │  │  │     │  ├─ Info.plist
│  │  │  │     │  ├─ Modules
│  │  │  │     │  │  ├─ module.modulemap
│  │  │  │     │  │  └─ url_launcher_ios.swiftmodule
│  │  │  │     │  │     ├─ Project
│  │  │  │     │  │     │  ├─ arm64-apple-ios-simulator.swiftsourceinfo
│  │  │  │     │  │     │  └─ x86_64-apple-ios-simulator.swiftsourceinfo
│  │  │  │     │  │     ├─ arm64-apple-ios-simulator.abi.json
│  │  │  │     │  │     ├─ arm64-apple-ios-simulator.swiftdoc
│  │  │  │     │  │     ├─ arm64-apple-ios-simulator.swiftmodule
│  │  │  │     │  │     ├─ x86_64-apple-ios-simulator.abi.json
│  │  │  │     │  │     ├─ x86_64-apple-ios-simulator.swiftdoc
│  │  │  │     │  │     └─ x86_64-apple-ios-simulator.swiftmodule
│  │  │  │     │  ├─ _CodeSignature
│  │  │  │     │  │  └─ CodeResources
│  │  │  │     │  ├─ url_launcher_ios
│  │  │  │     │  └─ url_launcher_ios_privacy.bundle
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     └─ PrivacyInfo.xcprivacy
│  │  │  │     └─ url_launcher_ios_privacy.bundle
│  │  │  │        ├─ Info.plist
│  │  │  │        └─ PrivacyInfo.xcprivacy
│  │  │  ├─ Release-iphoneos
│  │  │  │  ├─ .last_build_id
│  │  │  │  ├─ App.framework
│  │  │  │  │  ├─ App
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ flutter_assets
│  │  │  │  │     ├─ AssetManifest.bin
│  │  │  │  │     ├─ FontManifest.json
│  │  │  │  │     ├─ NOTICES.Z
│  │  │  │  │     ├─ NativeAssetsManifest.json
│  │  │  │  │     ├─ fonts
│  │  │  │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │  │     ├─ packages
│  │  │  │  │     │  └─ cupertino_icons
│  │  │  │  │     │     └─ assets
│  │  │  │  │     │        └─ CupertinoIcons.ttf
│  │  │  │  │     └─ shaders
│  │  │  │  │        ├─ ink_sparkle.frag
│  │  │  │  │        └─ stretch_effect.frag
│  │  │  │  ├─ App.framework.dSYM
│  │  │  │  │  └─ Contents
│  │  │  │  │     └─ Resources
│  │  │  │  │        └─ DWARF
│  │  │  │  │           └─ App
│  │  │  │  ├─ Flutter
│  │  │  │  ├─ Flutter.framework
│  │  │  │  │  ├─ Flutter
│  │  │  │  │  ├─ Headers
│  │  │  │  │  │  ├─ Flutter.h
│  │  │  │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │  │  │  ├─ FlutterChannels.h
│  │  │  │  │  │  ├─ FlutterCodecs.h
│  │  │  │  │  │  ├─ FlutterDartProject.h
│  │  │  │  │  │  ├─ FlutterEngine.h
│  │  │  │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │  │  │  ├─ FlutterHourFormat.h
│  │  │  │  │  │  ├─ FlutterMacros.h
│  │  │  │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │  │  │  ├─ FlutterPlugin.h
│  │  │  │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │  │  │  ├─ FlutterTexture.h
│  │  │  │  │  │  └─ FlutterViewController.h
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ Modules
│  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ icudtl.dat
│  │  │  │  ├─ Flutter.framework.dSYM
│  │  │  │  │  └─ Contents
│  │  │  │  │     ├─ Info.plist
│  │  │  │  │     └─ Resources
│  │  │  │  │        ├─ DWARF
│  │  │  │  │        │  └─ Flutter
│  │  │  │  │        └─ Relocations
│  │  │  │  │           └─ aarch64
│  │  │  │  │              └─ Flutter.yml
│  │  │  │  ├─ Pods_Runner.framework
│  │  │  │  │  ├─ Headers
│  │  │  │  │  │  └─ Pods-Runner-umbrella.h
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ Modules
│  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  └─ Pods_Runner
│  │  │  │  ├─ Runner.app
│  │  │  │  │  ├─ AppFrameworkInfo.plist
│  │  │  │  │  ├─ AppIcon60x60@2x.png
│  │  │  │  │  ├─ AppIcon76x76@2x~ipad.png
│  │  │  │  │  ├─ Assets.car
│  │  │  │  │  ├─ Base.lproj
│  │  │  │  │  │  ├─ LaunchScreen.storyboardc
│  │  │  │  │  │  │  ├─ 01J-lp-oVM-view-Ze5-6b-2t3.nib
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  └─ UIViewController-01J-lp-oVM.nib
│  │  │  │  │  │  └─ Main.storyboardc
│  │  │  │  │  │     ├─ BYZ-38-t0r-view-8bC-Xf-vdC.nib
│  │  │  │  │  │     ├─ Info.plist
│  │  │  │  │  │     └─ UIViewController-BYZ-38-t0r.nib
│  │  │  │  │  ├─ Frameworks
│  │  │  │  │  │  ├─ App.framework
│  │  │  │  │  │  │  ├─ App
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  │  │  └─ flutter_assets
│  │  │  │  │  │  │     ├─ AssetManifest.bin
│  │  │  │  │  │  │     ├─ FontManifest.json
│  │  │  │  │  │  │     ├─ NOTICES.Z
│  │  │  │  │  │  │     ├─ NativeAssetsManifest.json
│  │  │  │  │  │  │     ├─ fonts
│  │  │  │  │  │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │  │  │  │     ├─ packages
│  │  │  │  │  │  │     │  └─ cupertino_icons
│  │  │  │  │  │  │     │     └─ assets
│  │  │  │  │  │  │     │        └─ CupertinoIcons.ttf
│  │  │  │  │  │  │     └─ shaders
│  │  │  │  │  │  │        ├─ ink_sparkle.frag
│  │  │  │  │  │  │        └─ stretch_effect.frag
│  │  │  │  │  │  ├─ Flutter.framework
│  │  │  │  │  │  │  ├─ Flutter
│  │  │  │  │  │  │  ├─ Headers
│  │  │  │  │  │  │  │  ├─ Flutter.h
│  │  │  │  │  │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │  │  │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │  │  │  │  │  ├─ FlutterChannels.h
│  │  │  │  │  │  │  │  ├─ FlutterCodecs.h
│  │  │  │  │  │  │  │  ├─ FlutterDartProject.h
│  │  │  │  │  │  │  │  ├─ FlutterEngine.h
│  │  │  │  │  │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │  │  │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │  │  │  │  │  ├─ FlutterHourFormat.h
│  │  │  │  │  │  │  │  ├─ FlutterMacros.h
│  │  │  │  │  │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │  │  │  │  │  ├─ FlutterPlugin.h
│  │  │  │  │  │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │  │  │  │  │  ├─ FlutterTexture.h
│  │  │  │  │  │  │  │  └─ FlutterViewController.h
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  ├─ Modules
│  │  │  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  │  │  └─ icudtl.dat
│  │  │  │  │  │  └─ url_launcher_ios.framework
│  │  │  │  │  │     ├─ Info.plist
│  │  │  │  │  │     ├─ _CodeSignature
│  │  │  │  │  │     │  └─ CodeResources
│  │  │  │  │  │     ├─ url_launcher_ios
│  │  │  │  │  │     └─ url_launcher_ios_privacy.bundle
│  │  │  │  │  │        ├─ Info.plist
│  │  │  │  │  │        └─ PrivacyInfo.xcprivacy
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ PkgInfo
│  │  │  │  │  ├─ Runner
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ embedded.mobileprovision
│  │  │  │  ├─ Runner.app.dSYM
│  │  │  │  │  └─ Contents
│  │  │  │  │     ├─ Info.plist
│  │  │  │  │     └─ Resources
│  │  │  │  │        ├─ DWARF
│  │  │  │  │        │  └─ Runner
│  │  │  │  │        └─ Relocations
│  │  │  │  │           └─ aarch64
│  │  │  │  │              └─ Runner.yml
│  │  │  │  ├─ Runner.swiftmodule
│  │  │  │  │  ├─ Project
│  │  │  │  │  │  └─ arm64-apple-ios.swiftsourceinfo
│  │  │  │  │  ├─ arm64-apple-ios.abi.json
│  │  │  │  │  ├─ arm64-apple-ios.swiftdoc
│  │  │  │  │  └─ arm64-apple-ios.swiftmodule
│  │  │  │  └─ url_launcher_ios
│  │  │  │     ├─ url_launcher_ios.framework
│  │  │  │     │  ├─ Headers
│  │  │  │     │  │  ├─ url_launcher_ios-Swift.h
│  │  │  │     │  │  └─ url_launcher_ios-umbrella.h
│  │  │  │     │  ├─ Info.plist
│  │  │  │     │  ├─ Modules
│  │  │  │     │  │  ├─ module.modulemap
│  │  │  │     │  │  └─ url_launcher_ios.swiftmodule
│  │  │  │     │  │     ├─ Project
│  │  │  │     │  │     │  └─ arm64-apple-ios.swiftsourceinfo
│  │  │  │     │  │     ├─ arm64-apple-ios.abi.json
│  │  │  │     │  │     ├─ arm64-apple-ios.swiftdoc
│  │  │  │     │  │     └─ arm64-apple-ios.swiftmodule
│  │  │  │     │  ├─ url_launcher_ios
│  │  │  │     │  └─ url_launcher_ios_privacy.bundle
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     └─ PrivacyInfo.xcprivacy
│  │  │  │     ├─ url_launcher_ios.framework.dSYM
│  │  │  │     │  └─ Contents
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     └─ Resources
│  │  │  │     │        ├─ DWARF
│  │  │  │     │        │  └─ url_launcher_ios
│  │  │  │     │        └─ Relocations
│  │  │  │     │           └─ aarch64
│  │  │  │     │              └─ url_launcher_ios.yml
│  │  │  │     └─ url_launcher_ios_privacy.bundle
│  │  │  │        ├─ Info.plist
│  │  │  │        └─ PrivacyInfo.xcprivacy
│  │  │  ├─ XCBuildData
│  │  │  │  └─ PIFCache
│  │  │  │     ├─ project
│  │  │  │     │  └─ PROJECT@v11_mod=5930724f266fb45c8839b16fe3991b79_hash=bfdfe7dc352907fc980b868725387e98plugins=1OJSG6M1FOV3XYQCBH7Z29RZ0FPR9XDE1-json
│  │  │  │     ├─ target
│  │  │  │     │  ├─ TARGET@v11_hash=159265a1bff31e9959c56f1b8acc32d9-json
│  │  │  │     │  ├─ TARGET@v11_hash=780c2dd3829ed8480b56400f7c867488-json
│  │  │  │     │  ├─ TARGET@v11_hash=83e6b9aba0176010f8d31f24567f1965-json
│  │  │  │     │  ├─ TARGET@v11_hash=ec4c5e8870eb8a14b0566b4bb98a25e6-json
│  │  │  │     │  └─ TARGET@v11_hash=fcfb37e8bd3f89501bfa877d598628a8-json
│  │  │  │     └─ workspace
│  │  │  │        └─ WORKSPACE@v11_hash=(null)_subobjects=a48dd7d1b7a40ce152fc2ce6270ee19f-json
│  │  │  ├─ app-delta
│  │  │  ├─ framework_public_headers.fingerprint
│  │  │  ├─ iphoneos
│  │  │  │  └─ Runner.app
│  │  │  │     ├─ AppFrameworkInfo.plist
│  │  │  │     ├─ AppIcon60x60@2x.png
│  │  │  │     ├─ AppIcon76x76@2x~ipad.png
│  │  │  │     ├─ Assets.car
│  │  │  │     ├─ Base.lproj
│  │  │  │     │  ├─ LaunchScreen.storyboardc
│  │  │  │     │  │  ├─ 01J-lp-oVM-view-Ze5-6b-2t3.nib
│  │  │  │     │  │  ├─ Info.plist
│  │  │  │     │  │  └─ UIViewController-01J-lp-oVM.nib
│  │  │  │     │  └─ Main.storyboardc
│  │  │  │     │     ├─ BYZ-38-t0r-view-8bC-Xf-vdC.nib
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     └─ UIViewController-BYZ-38-t0r.nib
│  │  │  │     ├─ Frameworks
│  │  │  │     │  ├─ App.framework
│  │  │  │     │  │  ├─ App
│  │  │  │     │  │  ├─ Info.plist
│  │  │  │     │  │  ├─ _CodeSignature
│  │  │  │     │  │  │  └─ CodeResources
│  │  │  │     │  │  └─ flutter_assets
│  │  │  │     │  │     ├─ AssetManifest.bin
│  │  │  │     │  │     ├─ FontManifest.json
│  │  │  │     │  │     ├─ NOTICES.Z
│  │  │  │     │  │     ├─ NativeAssetsManifest.json
│  │  │  │     │  │     ├─ fonts
│  │  │  │     │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │     │  │     ├─ packages
│  │  │  │     │  │     │  └─ cupertino_icons
│  │  │  │     │  │     │     └─ assets
│  │  │  │     │  │     │        └─ CupertinoIcons.ttf
│  │  │  │     │  │     └─ shaders
│  │  │  │     │  │        ├─ ink_sparkle.frag
│  │  │  │     │  │        └─ stretch_effect.frag
│  │  │  │     │  ├─ Flutter.framework
│  │  │  │     │  │  ├─ Flutter
│  │  │  │     │  │  ├─ Headers
│  │  │  │     │  │  │  ├─ Flutter.h
│  │  │  │     │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │     │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │     │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │     │  │  │  ├─ FlutterChannels.h
│  │  │  │     │  │  │  ├─ FlutterCodecs.h
│  │  │  │     │  │  │  ├─ FlutterDartProject.h
│  │  │  │     │  │  │  ├─ FlutterEngine.h
│  │  │  │     │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │     │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │     │  │  │  ├─ FlutterHourFormat.h
│  │  │  │     │  │  │  ├─ FlutterMacros.h
│  │  │  │     │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │     │  │  │  ├─ FlutterPlugin.h
│  │  │  │     │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │     │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │     │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │     │  │  │  ├─ FlutterTexture.h
│  │  │  │     │  │  │  └─ FlutterViewController.h
│  │  │  │     │  │  ├─ Info.plist
│  │  │  │     │  │  ├─ Modules
│  │  │  │     │  │  │  └─ module.modulemap
│  │  │  │     │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │     │  │  ├─ _CodeSignature
│  │  │  │     │  │  │  └─ CodeResources
│  │  │  │     │  │  └─ icudtl.dat
│  │  │  │     │  └─ url_launcher_ios.framework
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     ├─ _CodeSignature
│  │  │  │     │     │  └─ CodeResources
│  │  │  │     │     ├─ url_launcher_ios
│  │  │  │     │     └─ url_launcher_ios_privacy.bundle
│  │  │  │     │        ├─ Info.plist
│  │  │  │     │        └─ PrivacyInfo.xcprivacy
│  │  │  │     ├─ Info.plist
│  │  │  │     ├─ PkgInfo
│  │  │  │     ├─ Runner
│  │  │  │     ├─ _CodeSignature
│  │  │  │     │  └─ CodeResources
│  │  │  │     └─ embedded.mobileprovision
│  │  │  ├─ iphonesimulator
│  │  │  │  └─ Runner.app
│  │  │  │     ├─ AppFrameworkInfo.plist
│  │  │  │     ├─ AppIcon60x60@2x.png
│  │  │  │     ├─ AppIcon76x76@2x~ipad.png
│  │  │  │     ├─ Assets.car
│  │  │  │     ├─ Base.lproj
│  │  │  │     │  ├─ LaunchScreen.storyboardc
│  │  │  │     │  │  ├─ 01J-lp-oVM-view-Ze5-6b-2t3.nib
│  │  │  │     │  │  ├─ Info.plist
│  │  │  │     │  │  └─ UIViewController-01J-lp-oVM.nib
│  │  │  │     │  └─ Main.storyboardc
│  │  │  │     │     ├─ BYZ-38-t0r-view-8bC-Xf-vdC.nib
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     └─ UIViewController-BYZ-38-t0r.nib
│  │  │  │     ├─ Frameworks
│  │  │  │     │  ├─ App.framework
│  │  │  │     │  │  ├─ App
│  │  │  │     │  │  ├─ Info.plist
│  │  │  │     │  │  ├─ _CodeSignature
│  │  │  │     │  │  │  └─ CodeResources
│  │  │  │     │  │  └─ flutter_assets
│  │  │  │     │  │     ├─ AssetManifest.bin
│  │  │  │     │  │     ├─ FontManifest.json
│  │  │  │     │  │     ├─ NOTICES.Z
│  │  │  │     │  │     ├─ NativeAssetsManifest.json
│  │  │  │     │  │     ├─ fonts
│  │  │  │     │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │     │  │     ├─ isolate_snapshot_data
│  │  │  │     │  │     ├─ kernel_blob.bin
│  │  │  │     │  │     ├─ packages
│  │  │  │     │  │     │  └─ cupertino_icons
│  │  │  │     │  │     │     └─ assets
│  │  │  │     │  │     │        └─ CupertinoIcons.ttf
│  │  │  │     │  │     ├─ shaders
│  │  │  │     │  │     │  ├─ ink_sparkle.frag
│  │  │  │     │  │     │  └─ stretch_effect.frag
│  │  │  │     │  │     └─ vm_snapshot_data
│  │  │  │     │  ├─ Flutter.framework
│  │  │  │     │  │  ├─ Flutter
│  │  │  │     │  │  ├─ Headers
│  │  │  │     │  │  │  ├─ Flutter.h
│  │  │  │     │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │     │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │     │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │     │  │  │  ├─ FlutterChannels.h
│  │  │  │     │  │  │  ├─ FlutterCodecs.h
│  │  │  │     │  │  │  ├─ FlutterDartProject.h
│  │  │  │     │  │  │  ├─ FlutterEngine.h
│  │  │  │     │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │     │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │     │  │  │  ├─ FlutterHourFormat.h
│  │  │  │     │  │  │  ├─ FlutterMacros.h
│  │  │  │     │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │     │  │  │  ├─ FlutterPlugin.h
│  │  │  │     │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │     │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │     │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │     │  │  │  ├─ FlutterTexture.h
│  │  │  │     │  │  │  └─ FlutterViewController.h
│  │  │  │     │  │  ├─ Info.plist
│  │  │  │     │  │  ├─ Modules
│  │  │  │     │  │  │  └─ module.modulemap
│  │  │  │     │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │     │  │  ├─ _CodeSignature
│  │  │  │     │  │  │  └─ CodeResources
│  │  │  │     │  │  └─ icudtl.dat
│  │  │  │     │  └─ url_launcher_ios.framework
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     ├─ _CodeSignature
│  │  │  │     │     │  └─ CodeResources
│  │  │  │     │     ├─ url_launcher_ios
│  │  │  │     │     └─ url_launcher_ios_privacy.bundle
│  │  │  │     │        ├─ Info.plist
│  │  │  │     │        └─ PrivacyInfo.xcprivacy
│  │  │  │     ├─ Info.plist
│  │  │  │     ├─ PkgInfo
│  │  │  │     ├─ Runner
│  │  │  │     ├─ Runner.debug.dylib
│  │  │  │     ├─ _CodeSignature
│  │  │  │     │  └─ CodeResources
│  │  │  │     └─ __preview.dylib
│  │  │  └─ pod_inputs.fingerprint
│  │  ├─ native_assets
│  │  │  └─ ios
│  │  └─ native_hooks
│  │     └─ .last_build_id
│  ├─ flutter_app.iml
│  ├─ ios
│  │  ├─ .symlinks
│  │  │  └─ plugins
│  │  │     └─ url_launcher_ios
│  │  │        ├─ AUTHORS
│  │  │        ├─ CHANGELOG.md
│  │  │        ├─ LICENSE
│  │  │        ├─ README.md
│  │  │        ├─ example
│  │  │        │  ├─ README.md
│  │  │        │  ├─ integration_test
│  │  │        │  │  └─ url_launcher_test.dart
│  │  │        │  ├─ ios
│  │  │        │  │  ├─ Flutter
│  │  │        │  │  │  ├─ AppFrameworkInfo.plist
│  │  │        │  │  │  ├─ Debug.xcconfig
│  │  │        │  │  │  └─ Release.xcconfig
│  │  │        │  │  ├─ Podfile
│  │  │        │  │  ├─ Runner
│  │  │        │  │  │  ├─ AppDelegate.swift
│  │  │        │  │  │  ├─ Assets.xcassets
│  │  │        │  │  │  │  ├─ AppIcon.appiconset
│  │  │        │  │  │  │  │  ├─ Contents.json
│  │  │        │  │  │  │  │  ├─ Icon-App-1024x1024@1x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-20x20@1x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-20x20@2x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-20x20@3x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-29x29@1x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-29x29@2x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-29x29@3x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-40x40@1x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-40x40@2x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-40x40@3x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-60x60@2x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-60x60@3x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-76x76@1x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-76x76@2x.png
│  │  │        │  │  │  │  │  └─ Icon-App-83.5x83.5@2x.png
│  │  │        │  │  │  │  └─ LaunchImage.imageset
│  │  │        │  │  │  │     ├─ Contents.json
│  │  │        │  │  │  │     ├─ LaunchImage.png
│  │  │        │  │  │  │     ├─ LaunchImage@2x.png
│  │  │        │  │  │  │     └─ LaunchImage@3x.png
│  │  │        │  │  │  ├─ Base.lproj
│  │  │        │  │  │  │  ├─ LaunchScreen.storyboard
│  │  │        │  │  │  │  └─ Main.storyboard
│  │  │        │  │  │  ├─ Info.plist
│  │  │        │  │  │  ├─ Runner-Bridging-Header.h
│  │  │        │  │  │  └─ SceneDelegate.swift
│  │  │        │  │  ├─ Runner.xcodeproj
│  │  │        │  │  │  ├─ project.pbxproj
│  │  │        │  │  │  ├─ project.xcworkspace
│  │  │        │  │  │  │  ├─ contents.xcworkspacedata
│  │  │        │  │  │  │  └─ xcshareddata
│  │  │        │  │  │  │     ├─ IDEWorkspaceChecks.plist
│  │  │        │  │  │  │     └─ WorkspaceSettings.xcsettings
│  │  │        │  │  │  └─ xcshareddata
│  │  │        │  │  │     └─ xcschemes
│  │  │        │  │  │        └─ Runner.xcscheme
│  │  │        │  │  ├─ Runner.xcworkspace
│  │  │        │  │  │  ├─ contents.xcworkspacedata
│  │  │        │  │  │  └─ xcshareddata
│  │  │        │  │  │     ├─ IDEWorkspaceChecks.plist
│  │  │        │  │  │     └─ WorkspaceSettings.xcsettings
│  │  │        │  │  ├─ RunnerTests
│  │  │        │  │  │  └─ URLLauncherTests.swift
│  │  │        │  │  └─ RunnerUITests
│  │  │        │  │     └─ URLLauncherUITests.swift
│  │  │        │  ├─ lib
│  │  │        │  │  └─ main.dart
│  │  │        │  ├─ pubspec.yaml
│  │  │        │  └─ test_driver
│  │  │        │     └─ integration_test.dart
│  │  │        ├─ ios
│  │  │        │  ├─ Assets
│  │  │        │  ├─ url_launcher_ios
│  │  │        │  │  ├─ Package.swift
│  │  │        │  │  └─ Sources
│  │  │        │  │     └─ url_launcher_ios
│  │  │        │  │        ├─ Launcher.swift
│  │  │        │  │        ├─ Resources
│  │  │        │  │        │  └─ PrivacyInfo.xcprivacy
│  │  │        │  │        ├─ URLLaunchSession.swift
│  │  │        │  │        ├─ URLLauncherPlugin.swift
│  │  │        │  │        ├─ ViewPresenter.swift
│  │  │        │  │        └─ messages.g.swift
│  │  │        │  └─ url_launcher_ios.podspec
│  │  │        ├─ lib
│  │  │        │  ├─ src
│  │  │        │  │  └─ messages.g.dart
│  │  │        │  └─ url_launcher_ios.dart
│  │  │        ├─ pigeons
│  │  │        │  ├─ copyright.txt
│  │  │        │  └─ messages.dart
│  │  │        ├─ pubspec.yaml
│  │  │        └─ test
│  │  │           ├─ url_launcher_ios_test.dart
│  │  │           └─ url_launcher_ios_test.mocks.dart
│  │  ├─ Flutter
│  │  │  ├─ AppFrameworkInfo.plist
│  │  │  ├─ Debug.xcconfig
│  │  │  ├─ Flutter.podspec
│  │  │  ├─ Generated.xcconfig
│  │  │  ├─ Release.xcconfig
│  │  │  ├─ ephemeral
│  │  │  │  ├─ flutter_lldb_helper.py
│  │  │  │  └─ flutter_lldbinit
│  │  │  └─ flutter_export_environment.sh
│  │  ├─ Podfile
│  │  ├─ Podfile.lock
│  │  ├─ Pods
│  │  │  ├─ Headers
│  │  │  ├─ Local Podspecs
│  │  │  │  ├─ Flutter.podspec.json
│  │  │  │  └─ url_launcher_ios.podspec.json
│  │  │  ├─ Manifest.lock
│  │  │  ├─ Pods.xcodeproj
│  │  │  │  ├─ project.pbxproj
│  │  │  │  └─ xcuserdata
│  │  │  │     └─ artemijsmykov.xcuserdatad
│  │  │  │        └─ xcschemes
│  │  │  │           ├─ Flutter.xcscheme
│  │  │  │           ├─ Pods-Runner.xcscheme
│  │  │  │           ├─ Pods-RunnerTests.xcscheme
│  │  │  │           ├─ url_launcher_ios-url_launcher_ios_privacy.xcscheme
│  │  │  │           ├─ url_launcher_ios.xcscheme
│  │  │  │           └─ xcschememanagement.plist
│  │  │  └─ Target Support Files
│  │  │     ├─ Flutter
│  │  │     │  ├─ Flutter.debug.xcconfig
│  │  │     │  └─ Flutter.release.xcconfig
│  │  │     ├─ Pods-Runner
│  │  │     │  ├─ Pods-Runner-Info.plist
│  │  │     │  ├─ Pods-Runner-acknowledgements.markdown
│  │  │     │  ├─ Pods-Runner-acknowledgements.plist
│  │  │     │  ├─ Pods-Runner-dummy.m
│  │  │     │  ├─ Pods-Runner-frameworks-Debug-input-files.xcfilelist
│  │  │     │  ├─ Pods-Runner-frameworks-Debug-output-files.xcfilelist
│  │  │     │  ├─ Pods-Runner-frameworks-Profile-input-files.xcfilelist
│  │  │     │  ├─ Pods-Runner-frameworks-Profile-output-files.xcfilelist
│  │  │     │  ├─ Pods-Runner-frameworks-Release-input-files.xcfilelist
│  │  │     │  ├─ Pods-Runner-frameworks-Release-output-files.xcfilelist
│  │  │     │  ├─ Pods-Runner-frameworks.sh
│  │  │     │  ├─ Pods-Runner-umbrella.h
│  │  │     │  ├─ Pods-Runner.debug.xcconfig
│  │  │     │  ├─ Pods-Runner.modulemap
│  │  │     │  ├─ Pods-Runner.profile.xcconfig
│  │  │     │  └─ Pods-Runner.release.xcconfig
│  │  │     ├─ Pods-RunnerTests
│  │  │     │  ├─ Pods-RunnerTests-Info.plist
│  │  │     │  ├─ Pods-RunnerTests-acknowledgements.markdown
│  │  │     │  ├─ Pods-RunnerTests-acknowledgements.plist
│  │  │     │  ├─ Pods-RunnerTests-dummy.m
│  │  │     │  ├─ Pods-RunnerTests-umbrella.h
│  │  │     │  ├─ Pods-RunnerTests.debug.xcconfig
│  │  │     │  ├─ Pods-RunnerTests.modulemap
│  │  │     │  ├─ Pods-RunnerTests.profile.xcconfig
│  │  │     │  └─ Pods-RunnerTests.release.xcconfig
│  │  │     └─ url_launcher_ios
│  │  │        ├─ ResourceBundle-url_launcher_ios_privacy-url_launcher_ios-Info.plist
│  │  │        ├─ url_launcher_ios-Info.plist
│  │  │        ├─ url_launcher_ios-dummy.m
│  │  │        ├─ url_launcher_ios-prefix.pch
│  │  │        ├─ url_launcher_ios-umbrella.h
│  │  │        ├─ url_launcher_ios.debug.xcconfig
│  │  │        ├─ url_launcher_ios.modulemap
│  │  │        └─ url_launcher_ios.release.xcconfig
│  │  ├─ Runner
│  │  │  ├─ AppDelegate.swift
│  │  │  ├─ Assets.xcassets
│  │  │  │  ├─ AppIcon.appiconset
│  │  │  │  │  ├─ Contents.json
│  │  │  │  │  ├─ Icon-App-1024x1024@1x.png
│  │  │  │  │  ├─ Icon-App-20x20@1x.png
│  │  │  │  │  ├─ Icon-App-20x20@2x.png
│  │  │  │  │  ├─ Icon-App-20x20@3x.png
│  │  │  │  │  ├─ Icon-App-29x29@1x.png
│  │  │  │  │  ├─ Icon-App-29x29@2x.png
│  │  │  │  │  ├─ Icon-App-29x29@3x.png
│  │  │  │  │  ├─ Icon-App-40x40@1x.png
│  │  │  │  │  ├─ Icon-App-40x40@2x.png
│  │  │  │  │  ├─ Icon-App-40x40@3x.png
│  │  │  │  │  ├─ Icon-App-50x50@1x.png
│  │  │  │  │  ├─ Icon-App-50x50@2x.png
│  │  │  │  │  ├─ Icon-App-57x57@1x.png
│  │  │  │  │  ├─ Icon-App-57x57@2x.png
│  │  │  │  │  ├─ Icon-App-60x60@2x.png
│  │  │  │  │  ├─ Icon-App-60x60@3x.png
│  │  │  │  │  ├─ Icon-App-72x72@1x.png
│  │  │  │  │  ├─ Icon-App-72x72@2x.png
│  │  │  │  │  ├─ Icon-App-76x76@1x.png
│  │  │  │  │  ├─ Icon-App-76x76@2x.png
│  │  │  │  │  └─ Icon-App-83.5x83.5@2x.png
│  │  │  │  └─ LaunchImage.imageset
│  │  │  │     ├─ Contents.json
│  │  │  │     ├─ LaunchImage.png
│  │  │  │     ├─ LaunchImage@2x.png
│  │  │  │     ├─ LaunchImage@3x.png
│  │  │  │     └─ README.md
│  │  │  ├─ Base.lproj
│  │  │  │  ├─ LaunchScreen.storyboard
│  │  │  │  └─ Main.storyboard
│  │  │  ├─ GeneratedPluginRegistrant.h
│  │  │  ├─ GeneratedPluginRegistrant.m
│  │  │  ├─ Info.plist
│  │  │  ├─ Runner-Bridging-Header.h
│  │  │  └─ SceneDelegate.swift
│  │  ├─ Runner.xcodeproj
│  │  │  ├─ project.pbxproj
│  │  │  ├─ project.xcworkspace
│  │  │  │  ├─ contents.xcworkspacedata
│  │  │  │  └─ xcshareddata
│  │  │  │     ├─ IDEWorkspaceChecks.plist
│  │  │  │     ├─ WorkspaceSettings.xcsettings
│  │  │  │     └─ swiftpm
│  │  │  │        └─ configuration
│  │  │  └─ xcshareddata
│  │  │     └─ xcschemes
│  │  │        └─ Runner.xcscheme
│  │  ├─ Runner.xcworkspace
│  │  │  ├─ contents.xcworkspacedata
│  │  │  ├─ xcshareddata
│  │  │  │  ├─ IDEWorkspaceChecks.plist
│  │  │  │  ├─ WorkspaceSettings.xcsettings
│  │  │  │  └─ swiftpm
│  │  │  │     └─ configuration
│  │  │  └─ xcuserdata
│  │  │     └─ artemijsmykov.xcuserdatad
│  │  │        └─ UserInterfaceState.xcuserstate
│  │  └─ RunnerTests
│  │     └─ RunnerTests.swift
│  ├─ lib
│  │  ├─ core
│  │  │  ├─ api
│  │  │  │  └─ api_client.dart
│  │  │  └─ models
│  │  │     ├─ analysis_result.dart
│  │  │     ├─ domain_stats.dart
│  │  │     ├─ feed_item.dart
│  │  │     └─ history_item.dart
│  │  ├─ features
│  │  │  ├─ analysis
│  │  │  │  ├─ providers
│  │  │  │  │  └─ analysis_provider.dart
│  │  │  │  ├─ screens
│  │  │  │  │  ├─ analysis_screen.dart
│  │  │  │  │  └─ history_screen.dart
│  │  │  │  └─ widgets
│  │  │  │     └─ verdict_card.dart
│  │  │  ├─ feed
│  │  │  │  └─ screens
│  │  │  │     ├─ feed_screen.dart
│  │  │  │     └─ news_detail_screen.dart
│  │  │  ├─ graph
│  │  │  │  └─ screens
│  │  │  │     └─ graph_screen.dart
│  │  │  └─ sources
│  │  │     └─ screens
│  │  │        ├─ domain_stats_screen.dart
│  │  │        └─ sources_screen.dart
│  │  ├─ main.dart
│  │  └─ shared
│  │     └─ theme
│  ├─ pubspec.lock
│  ├─ pubspec.yaml
│  └─ test
│     └─ widget_test.dart
└─ requirements.txt

```
```
fakescope
├─ README.md
├─ backend
│  ├─ Dockerfile
│  ├─ app
│  │  ├─ __init__.py
│  │  ├─ api
│  │  │  ├─ __init__.py
│  │  │  └─ routes
│  │  │     ├─ __init__.py
│  │  │     ├─ analysis.py
│  │  │     ├─ domains.py
│  │  │     ├─ feed.py
│  │  │     ├─ graph.py
│  │  │     └─ sources.py
│  │  ├─ core
│  │  │  ├─ __init__.py
│  │  │  ├─ config.py
│  │  │  ├─ database.py
│  │  │  ├─ google_credentials.json
│  │  │  └─ seed_sources.py
│  │  ├─ main.py
│  │  ├─ models
│  │  │  ├─ __init__.py
│  │  │  ├─ analysis.py
│  │  │  └─ db_models.py
│  │  ├─ modules
│  │  │  ├─ __init__.py
│  │  │  ├─ factcheck
│  │  │  │  ├─ __init__.py
│  │  │  │  ├─ checker.py
│  │  │  │  ├─ data
│  │  │  │  │  └─ facts.json
│  │  │  │  └─ google_factcheck.py
│  │  │  ├─ feed
│  │  │  │  ├─ __init__.py
│  │  │  │  └─ rss_fetcher.py
│  │  │  ├─ network
│  │  │  │  ├─ __init__.py
│  │  │  │  └─ spread_analyzer.py
│  │  │  ├─ nlp
│  │  │  │  ├─ __init__.py
│  │  │  │  ├─ analyzer.py
│  │  │  │  └─ topic_classifier.py
│  │  │  └─ sources
│  │  │     ├─ __init__.py
│  │  │     ├─ domain_analyzer.py
│  │  │     ├─ domain_database.py
│  │  │     └─ domains.json
│  │  └─ services
│  │     ├─ __init__.py
│  │     └─ feed_service.py
│  ├─ populate_faiss.py
│  ├─ requirements.txt
│  └─ tests
├─ docker-compose.yml
├─ docs
│  └─ screenshots
│     ├─ analyze.png
│     ├─ domain_stats.png
│     ├─ feed.png
│     ├─ graph.png
│     ├─ history.png
│     ├─ result.png
│     └─ sources.png
├─ flutter_app
│  ├─ .dart_tool
│  │  ├─ extension_discovery
│  │  │  ├─ README.md
│  │  │  └─ vs_code.json
│  │  ├─ flutter_build
│  │  │  ├─ 25c6d19ea9370463c51c8be7fa976ec2
│  │  │  │  ├─ .filecache
│  │  │  │  ├─ App.framework
│  │  │  │  │  └─ App
│  │  │  │  ├─ IssueLaunchRootViewControllerAccess.stamp
│  │  │  │  ├─ app.dill
│  │  │  │  ├─ dart_build.d
│  │  │  │  ├─ dart_build.stamp
│  │  │  │  ├─ dart_build_result.json
│  │  │  │  ├─ debug_ios_bundle_flutter_assets.stamp
│  │  │  │  ├─ debug_ios_lldb_init.stamp
│  │  │  │  ├─ debug_universal_framework.stamp
│  │  │  │  ├─ debug_unpack_ios.stamp
│  │  │  │  ├─ flutter_assets.d
│  │  │  │  ├─ gen_dart_plugin_registrant.stamp
│  │  │  │  ├─ gen_localizations.stamp
│  │  │  │  ├─ install_code_assets.d
│  │  │  │  ├─ install_code_assets.stamp
│  │  │  │  ├─ kernel_snapshot_program.d
│  │  │  │  ├─ kernel_snapshot_program.stamp
│  │  │  │  ├─ native_assets.json
│  │  │  │  └─ outputs.json
│  │  │  ├─ 47b497430f58a7c299da59b51d43c2b3
│  │  │  │  ├─ .filecache
│  │  │  │  ├─ App.framework
│  │  │  │  │  └─ App
│  │  │  │  ├─ IssueLaunchRootViewControllerAccess.stamp
│  │  │  │  ├─ app.dill
│  │  │  │  ├─ dart_build.d
│  │  │  │  ├─ dart_build.stamp
│  │  │  │  ├─ dart_build_result.json
│  │  │  │  ├─ debug_ios_bundle_flutter_assets.stamp
│  │  │  │  ├─ debug_ios_lldb_init.stamp
│  │  │  │  ├─ debug_universal_framework.stamp
│  │  │  │  ├─ debug_unpack_ios.stamp
│  │  │  │  ├─ flutter_assets.d
│  │  │  │  ├─ gen_dart_plugin_registrant.stamp
│  │  │  │  ├─ gen_localizations.stamp
│  │  │  │  ├─ install_code_assets.d
│  │  │  │  ├─ install_code_assets.stamp
│  │  │  │  ├─ kernel_snapshot_program.d
│  │  │  │  ├─ kernel_snapshot_program.stamp
│  │  │  │  ├─ native_assets.json
│  │  │  │  └─ outputs.json
│  │  │  ├─ dart_plugin_registrant.dart
│  │  │  └─ ee06b376487f90ebfc2337ea6b3baed2
│  │  │     ├─ .filecache
│  │  │     ├─ App.framework
│  │  │     │  └─ App
│  │  │     ├─ App.framework.dSYM
│  │  │     │  └─ Contents
│  │  │     │     └─ Resources
│  │  │     │        └─ DWARF
│  │  │     │           └─ App
│  │  │     ├─ aot_assembly_release.stamp
│  │  │     ├─ app.dill
│  │  │     ├─ arm64
│  │  │     │  ├─ App.framework
│  │  │     │  │  └─ App
│  │  │     │  ├─ App.framework.dSYM
│  │  │     │  │  └─ Contents
│  │  │     │  │     ├─ Info.plist
│  │  │     │  │     └─ Resources
│  │  │     │  │        ├─ DWARF
│  │  │     │  │        │  └─ App
│  │  │     │  │        └─ Relocations
│  │  │     │  │           └─ aarch64
│  │  │     │  │              └─ App.yml
│  │  │     │  ├─ snapshot_assembly.S
│  │  │     │  └─ snapshot_assembly.o
│  │  │     ├─ dart_build.d
│  │  │     ├─ dart_build.stamp
│  │  │     ├─ dart_build_result.json
│  │  │     ├─ flutter_assets.d
│  │  │     ├─ gen_dart_plugin_registrant.stamp
│  │  │     ├─ gen_localizations.stamp
│  │  │     ├─ install_code_assets.d
│  │  │     ├─ install_code_assets.stamp
│  │  │     ├─ kernel_snapshot_program.d
│  │  │     ├─ kernel_snapshot_program.stamp
│  │  │     ├─ native_assets.json
│  │  │     ├─ outputs.json
│  │  │     ├─ release_ios_bundle_flutter_assets.stamp
│  │  │     └─ release_unpack_ios.stamp
│  │  ├─ package_config.json
│  │  ├─ package_graph.json
│  │  └─ version
│  ├─ .flutter-plugins-dependencies
│  ├─ .idea
│  │  ├─ libraries
│  │  │  ├─ Dart_SDK.xml
│  │  │  └─ KotlinJavaRuntime.xml
│  │  ├─ modules.xml
│  │  ├─ runConfigurations
│  │  │  └─ main_dart.xml
│  │  └─ workspace.xml
│  ├─ .metadata
│  ├─ README.md
│  ├─ analysis_options.yaml
│  ├─ android
│  │  ├─ app
│  │  │  ├─ build.gradle.kts
│  │  │  └─ src
│  │  │     ├─ debug
│  │  │     │  └─ AndroidManifest.xml
│  │  │     ├─ main
│  │  │     │  ├─ AndroidManifest.xml
│  │  │     │  ├─ java
│  │  │     │  │  └─ io
│  │  │     │  │     └─ flutter
│  │  │     │  │        └─ plugins
│  │  │     │  │           └─ GeneratedPluginRegistrant.java
│  │  │     │  ├─ kotlin
│  │  │     │  │  └─ com
│  │  │     │  │     └─ fakescope
│  │  │     │  │        └─ flutter_app
│  │  │     │  │           └─ MainActivity.kt
│  │  │     │  └─ res
│  │  │     │     ├─ drawable
│  │  │     │     │  └─ launch_background.xml
│  │  │     │     ├─ drawable-v21
│  │  │     │     │  └─ launch_background.xml
│  │  │     │     ├─ mipmap-hdpi
│  │  │     │     │  └─ ic_launcher.png
│  │  │     │     ├─ mipmap-mdpi
│  │  │     │     │  └─ ic_launcher.png
│  │  │     │     ├─ mipmap-xhdpi
│  │  │     │     │  └─ ic_launcher.png
│  │  │     │     ├─ mipmap-xxhdpi
│  │  │     │     │  └─ ic_launcher.png
│  │  │     │     ├─ mipmap-xxxhdpi
│  │  │     │     │  └─ ic_launcher.png
│  │  │     │     ├─ values
│  │  │     │     │  └─ styles.xml
│  │  │     │     └─ values-night
│  │  │     │        └─ styles.xml
│  │  │     └─ profile
│  │  │        └─ AndroidManifest.xml
│  │  ├─ build.gradle.kts
│  │  ├─ flutter_app_android.iml
│  │  ├─ gradle
│  │  │  └─ wrapper
│  │  │     ├─ gradle-wrapper.jar
│  │  │     └─ gradle-wrapper.properties
│  │  ├─ gradle.properties
│  │  ├─ gradlew
│  │  ├─ gradlew.bat
│  │  ├─ local.properties
│  │  └─ settings.gradle.kts
│  ├─ assets
│  │  └─ icon
│  │     └─ icon.png
│  ├─ build
│  │  ├─ 6f4a15e49d0bc622ec76656f5f470141.cache.dill.track.dill
│  │  ├─ 7670a5c233f355cb86e3dcb68d73a9a3
│  │  │  ├─ .filecache
│  │  │  ├─ _composite.stamp
│  │  │  ├─ dart_build.d
│  │  │  ├─ dart_build.stamp
│  │  │  ├─ dart_build_result.json
│  │  │  ├─ gen_dart_plugin_registrant.stamp
│  │  │  ├─ gen_localizations.stamp
│  │  │  └─ outputs.json
│  │  ├─ ios
│  │  │  ├─ Debug-iphoneos
│  │  │  │  ├─ .last_build_id
│  │  │  │  ├─ App.framework
│  │  │  │  │  ├─ App
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ flutter_assets
│  │  │  │  │     ├─ AssetManifest.bin
│  │  │  │  │     ├─ FontManifest.json
│  │  │  │  │     ├─ NOTICES.Z
│  │  │  │  │     ├─ NativeAssetsManifest.json
│  │  │  │  │     ├─ fonts
│  │  │  │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │  │     ├─ isolate_snapshot_data
│  │  │  │  │     ├─ kernel_blob.bin
│  │  │  │  │     ├─ packages
│  │  │  │  │     │  └─ cupertino_icons
│  │  │  │  │     │     └─ assets
│  │  │  │  │     │        └─ CupertinoIcons.ttf
│  │  │  │  │     ├─ shaders
│  │  │  │  │     │  ├─ ink_sparkle.frag
│  │  │  │  │     │  └─ stretch_effect.frag
│  │  │  │  │     └─ vm_snapshot_data
│  │  │  │  ├─ Flutter
│  │  │  │  ├─ Flutter.framework
│  │  │  │  │  ├─ Flutter
│  │  │  │  │  ├─ Headers
│  │  │  │  │  │  ├─ Flutter.h
│  │  │  │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │  │  │  ├─ FlutterChannels.h
│  │  │  │  │  │  ├─ FlutterCodecs.h
│  │  │  │  │  │  ├─ FlutterDartProject.h
│  │  │  │  │  │  ├─ FlutterEngine.h
│  │  │  │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │  │  │  ├─ FlutterHourFormat.h
│  │  │  │  │  │  ├─ FlutterMacros.h
│  │  │  │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │  │  │  ├─ FlutterPlugin.h
│  │  │  │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │  │  │  ├─ FlutterTexture.h
│  │  │  │  │  │  └─ FlutterViewController.h
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ Modules
│  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ icudtl.dat
│  │  │  │  ├─ Pods_Runner.framework
│  │  │  │  │  ├─ Headers
│  │  │  │  │  │  └─ Pods-Runner-umbrella.h
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ Modules
│  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  └─ Pods_Runner
│  │  │  │  ├─ Runner.app
│  │  │  │  │  ├─ AppFrameworkInfo.plist
│  │  │  │  │  ├─ AppIcon60x60@2x.png
│  │  │  │  │  ├─ AppIcon76x76@2x~ipad.png
│  │  │  │  │  ├─ Assets.car
│  │  │  │  │  ├─ Base.lproj
│  │  │  │  │  │  ├─ LaunchScreen.storyboardc
│  │  │  │  │  │  │  ├─ 01J-lp-oVM-view-Ze5-6b-2t3.nib
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  └─ UIViewController-01J-lp-oVM.nib
│  │  │  │  │  │  └─ Main.storyboardc
│  │  │  │  │  │     ├─ BYZ-38-t0r-view-8bC-Xf-vdC.nib
│  │  │  │  │  │     ├─ Info.plist
│  │  │  │  │  │     └─ UIViewController-BYZ-38-t0r.nib
│  │  │  │  │  ├─ Frameworks
│  │  │  │  │  │  ├─ App.framework
│  │  │  │  │  │  │  ├─ App
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  │  │  └─ flutter_assets
│  │  │  │  │  │  │     ├─ AssetManifest.bin
│  │  │  │  │  │  │     ├─ FontManifest.json
│  │  │  │  │  │  │     ├─ NOTICES.Z
│  │  │  │  │  │  │     ├─ NativeAssetsManifest.json
│  │  │  │  │  │  │     ├─ fonts
│  │  │  │  │  │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │  │  │  │     ├─ isolate_snapshot_data
│  │  │  │  │  │  │     ├─ kernel_blob.bin
│  │  │  │  │  │  │     ├─ packages
│  │  │  │  │  │  │     │  └─ cupertino_icons
│  │  │  │  │  │  │     │     └─ assets
│  │  │  │  │  │  │     │        └─ CupertinoIcons.ttf
│  │  │  │  │  │  │     ├─ shaders
│  │  │  │  │  │  │     │  ├─ ink_sparkle.frag
│  │  │  │  │  │  │     │  └─ stretch_effect.frag
│  │  │  │  │  │  │     └─ vm_snapshot_data
│  │  │  │  │  │  ├─ Flutter.framework
│  │  │  │  │  │  │  ├─ Flutter
│  │  │  │  │  │  │  ├─ Headers
│  │  │  │  │  │  │  │  ├─ Flutter.h
│  │  │  │  │  │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │  │  │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │  │  │  │  │  ├─ FlutterChannels.h
│  │  │  │  │  │  │  │  ├─ FlutterCodecs.h
│  │  │  │  │  │  │  │  ├─ FlutterDartProject.h
│  │  │  │  │  │  │  │  ├─ FlutterEngine.h
│  │  │  │  │  │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │  │  │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │  │  │  │  │  ├─ FlutterHourFormat.h
│  │  │  │  │  │  │  │  ├─ FlutterMacros.h
│  │  │  │  │  │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │  │  │  │  │  ├─ FlutterPlugin.h
│  │  │  │  │  │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │  │  │  │  │  ├─ FlutterTexture.h
│  │  │  │  │  │  │  │  └─ FlutterViewController.h
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  ├─ Modules
│  │  │  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  │  │  └─ icudtl.dat
│  │  │  │  │  │  └─ url_launcher_ios.framework
│  │  │  │  │  │     ├─ Info.plist
│  │  │  │  │  │     ├─ _CodeSignature
│  │  │  │  │  │     │  └─ CodeResources
│  │  │  │  │  │     ├─ url_launcher_ios
│  │  │  │  │  │     └─ url_launcher_ios_privacy.bundle
│  │  │  │  │  │        ├─ Info.plist
│  │  │  │  │  │        └─ PrivacyInfo.xcprivacy
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ PkgInfo
│  │  │  │  │  ├─ Runner
│  │  │  │  │  ├─ Runner.debug.dylib
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  ├─ __preview.dylib
│  │  │  │  │  └─ embedded.mobileprovision
│  │  │  │  ├─ Runner.swiftmodule
│  │  │  │  │  ├─ Project
│  │  │  │  │  │  └─ arm64-apple-ios.swiftsourceinfo
│  │  │  │  │  ├─ arm64-apple-ios.abi.json
│  │  │  │  │  ├─ arm64-apple-ios.swiftdoc
│  │  │  │  │  └─ arm64-apple-ios.swiftmodule
│  │  │  │  └─ url_launcher_ios
│  │  │  │     ├─ url_launcher_ios.framework
│  │  │  │     │  ├─ Headers
│  │  │  │     │  │  ├─ url_launcher_ios-Swift.h
│  │  │  │     │  │  └─ url_launcher_ios-umbrella.h
│  │  │  │     │  ├─ Info.plist
│  │  │  │     │  ├─ Modules
│  │  │  │     │  │  ├─ module.modulemap
│  │  │  │     │  │  └─ url_launcher_ios.swiftmodule
│  │  │  │     │  │     ├─ Project
│  │  │  │     │  │     │  └─ arm64-apple-ios.swiftsourceinfo
│  │  │  │     │  │     ├─ arm64-apple-ios.abi.json
│  │  │  │     │  │     ├─ arm64-apple-ios.swiftdoc
│  │  │  │     │  │     └─ arm64-apple-ios.swiftmodule
│  │  │  │     │  ├─ url_launcher_ios
│  │  │  │     │  └─ url_launcher_ios_privacy.bundle
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     └─ PrivacyInfo.xcprivacy
│  │  │  │     └─ url_launcher_ios_privacy.bundle
│  │  │  │        ├─ Info.plist
│  │  │  │        └─ PrivacyInfo.xcprivacy
│  │  │  ├─ Debug-iphonesimulator
│  │  │  │  ├─ .last_build_id
│  │  │  │  ├─ App.framework
│  │  │  │  │  ├─ App
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ flutter_assets
│  │  │  │  │     ├─ AssetManifest.bin
│  │  │  │  │     ├─ FontManifest.json
│  │  │  │  │     ├─ NOTICES.Z
│  │  │  │  │     ├─ NativeAssetsManifest.json
│  │  │  │  │     ├─ fonts
│  │  │  │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │  │     ├─ isolate_snapshot_data
│  │  │  │  │     ├─ kernel_blob.bin
│  │  │  │  │     ├─ packages
│  │  │  │  │     │  └─ cupertino_icons
│  │  │  │  │     │     └─ assets
│  │  │  │  │     │        └─ CupertinoIcons.ttf
│  │  │  │  │     ├─ shaders
│  │  │  │  │     │  ├─ ink_sparkle.frag
│  │  │  │  │     │  └─ stretch_effect.frag
│  │  │  │  │     └─ vm_snapshot_data
│  │  │  │  ├─ Flutter
│  │  │  │  ├─ Flutter.framework
│  │  │  │  │  ├─ Flutter
│  │  │  │  │  ├─ Headers
│  │  │  │  │  │  ├─ Flutter.h
│  │  │  │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │  │  │  ├─ FlutterChannels.h
│  │  │  │  │  │  ├─ FlutterCodecs.h
│  │  │  │  │  │  ├─ FlutterDartProject.h
│  │  │  │  │  │  ├─ FlutterEngine.h
│  │  │  │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │  │  │  ├─ FlutterHourFormat.h
│  │  │  │  │  │  ├─ FlutterMacros.h
│  │  │  │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │  │  │  ├─ FlutterPlugin.h
│  │  │  │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │  │  │  ├─ FlutterTexture.h
│  │  │  │  │  │  └─ FlutterViewController.h
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ Modules
│  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ icudtl.dat
│  │  │  │  ├─ Pods_Runner.framework
│  │  │  │  │  ├─ Headers
│  │  │  │  │  │  └─ Pods-Runner-umbrella.h
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ Modules
│  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  ├─ Pods_Runner
│  │  │  │  │  └─ _CodeSignature
│  │  │  │  │     ├─ CodeDirectory
│  │  │  │  │     ├─ CodeRequirements
│  │  │  │  │     ├─ CodeResources
│  │  │  │  │     └─ CodeSignature
│  │  │  │  ├─ Runner.app
│  │  │  │  │  ├─ AppFrameworkInfo.plist
│  │  │  │  │  ├─ AppIcon60x60@2x.png
│  │  │  │  │  ├─ AppIcon76x76@2x~ipad.png
│  │  │  │  │  ├─ Assets.car
│  │  │  │  │  ├─ Base.lproj
│  │  │  │  │  │  ├─ LaunchScreen.storyboardc
│  │  │  │  │  │  │  ├─ 01J-lp-oVM-view-Ze5-6b-2t3.nib
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  └─ UIViewController-01J-lp-oVM.nib
│  │  │  │  │  │  └─ Main.storyboardc
│  │  │  │  │  │     ├─ BYZ-38-t0r-view-8bC-Xf-vdC.nib
│  │  │  │  │  │     ├─ Info.plist
│  │  │  │  │  │     └─ UIViewController-BYZ-38-t0r.nib
│  │  │  │  │  ├─ Frameworks
│  │  │  │  │  │  ├─ App.framework
│  │  │  │  │  │  │  ├─ App
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  │  │  └─ flutter_assets
│  │  │  │  │  │  │     ├─ AssetManifest.bin
│  │  │  │  │  │  │     ├─ FontManifest.json
│  │  │  │  │  │  │     ├─ NOTICES.Z
│  │  │  │  │  │  │     ├─ NativeAssetsManifest.json
│  │  │  │  │  │  │     ├─ fonts
│  │  │  │  │  │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │  │  │  │     ├─ isolate_snapshot_data
│  │  │  │  │  │  │     ├─ kernel_blob.bin
│  │  │  │  │  │  │     ├─ packages
│  │  │  │  │  │  │     │  └─ cupertino_icons
│  │  │  │  │  │  │     │     └─ assets
│  │  │  │  │  │  │     │        └─ CupertinoIcons.ttf
│  │  │  │  │  │  │     ├─ shaders
│  │  │  │  │  │  │     │  ├─ ink_sparkle.frag
│  │  │  │  │  │  │     │  └─ stretch_effect.frag
│  │  │  │  │  │  │     └─ vm_snapshot_data
│  │  │  │  │  │  ├─ Flutter.framework
│  │  │  │  │  │  │  ├─ Flutter
│  │  │  │  │  │  │  ├─ Headers
│  │  │  │  │  │  │  │  ├─ Flutter.h
│  │  │  │  │  │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │  │  │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │  │  │  │  │  ├─ FlutterChannels.h
│  │  │  │  │  │  │  │  ├─ FlutterCodecs.h
│  │  │  │  │  │  │  │  ├─ FlutterDartProject.h
│  │  │  │  │  │  │  │  ├─ FlutterEngine.h
│  │  │  │  │  │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │  │  │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │  │  │  │  │  ├─ FlutterHourFormat.h
│  │  │  │  │  │  │  │  ├─ FlutterMacros.h
│  │  │  │  │  │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │  │  │  │  │  ├─ FlutterPlugin.h
│  │  │  │  │  │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │  │  │  │  │  ├─ FlutterTexture.h
│  │  │  │  │  │  │  │  └─ FlutterViewController.h
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  ├─ Modules
│  │  │  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  │  │  └─ icudtl.dat
│  │  │  │  │  │  └─ url_launcher_ios.framework
│  │  │  │  │  │     ├─ Info.plist
│  │  │  │  │  │     ├─ _CodeSignature
│  │  │  │  │  │     │  └─ CodeResources
│  │  │  │  │  │     ├─ url_launcher_ios
│  │  │  │  │  │     └─ url_launcher_ios_privacy.bundle
│  │  │  │  │  │        ├─ Info.plist
│  │  │  │  │  │        └─ PrivacyInfo.xcprivacy
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ PkgInfo
│  │  │  │  │  ├─ Runner
│  │  │  │  │  ├─ Runner.debug.dylib
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ __preview.dylib
│  │  │  │  ├─ Runner.swiftmodule
│  │  │  │  │  ├─ Project
│  │  │  │  │  │  └─ arm64-apple-ios-simulator.swiftsourceinfo
│  │  │  │  │  ├─ arm64-apple-ios-simulator.abi.json
│  │  │  │  │  ├─ arm64-apple-ios-simulator.swiftdoc
│  │  │  │  │  └─ arm64-apple-ios-simulator.swiftmodule
│  │  │  │  └─ url_launcher_ios
│  │  │  │     ├─ url_launcher_ios.framework
│  │  │  │     │  ├─ Headers
│  │  │  │     │  │  ├─ url_launcher_ios-Swift.h
│  │  │  │     │  │  └─ url_launcher_ios-umbrella.h
│  │  │  │     │  ├─ Info.plist
│  │  │  │     │  ├─ Modules
│  │  │  │     │  │  ├─ module.modulemap
│  │  │  │     │  │  └─ url_launcher_ios.swiftmodule
│  │  │  │     │  │     ├─ Project
│  │  │  │     │  │     │  ├─ arm64-apple-ios-simulator.swiftsourceinfo
│  │  │  │     │  │     │  └─ x86_64-apple-ios-simulator.swiftsourceinfo
│  │  │  │     │  │     ├─ arm64-apple-ios-simulator.abi.json
│  │  │  │     │  │     ├─ arm64-apple-ios-simulator.swiftdoc
│  │  │  │     │  │     ├─ arm64-apple-ios-simulator.swiftmodule
│  │  │  │     │  │     ├─ x86_64-apple-ios-simulator.abi.json
│  │  │  │     │  │     ├─ x86_64-apple-ios-simulator.swiftdoc
│  │  │  │     │  │     └─ x86_64-apple-ios-simulator.swiftmodule
│  │  │  │     │  ├─ _CodeSignature
│  │  │  │     │  │  └─ CodeResources
│  │  │  │     │  ├─ url_launcher_ios
│  │  │  │     │  └─ url_launcher_ios_privacy.bundle
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     └─ PrivacyInfo.xcprivacy
│  │  │  │     └─ url_launcher_ios_privacy.bundle
│  │  │  │        ├─ Info.plist
│  │  │  │        └─ PrivacyInfo.xcprivacy
│  │  │  ├─ Release-iphoneos
│  │  │  │  ├─ .last_build_id
│  │  │  │  ├─ App.framework
│  │  │  │  │  ├─ App
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ flutter_assets
│  │  │  │  │     ├─ AssetManifest.bin
│  │  │  │  │     ├─ FontManifest.json
│  │  │  │  │     ├─ NOTICES.Z
│  │  │  │  │     ├─ NativeAssetsManifest.json
│  │  │  │  │     ├─ fonts
│  │  │  │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │  │     ├─ packages
│  │  │  │  │     │  └─ cupertino_icons
│  │  │  │  │     │     └─ assets
│  │  │  │  │     │        └─ CupertinoIcons.ttf
│  │  │  │  │     └─ shaders
│  │  │  │  │        ├─ ink_sparkle.frag
│  │  │  │  │        └─ stretch_effect.frag
│  │  │  │  ├─ App.framework.dSYM
│  │  │  │  │  └─ Contents
│  │  │  │  │     └─ Resources
│  │  │  │  │        └─ DWARF
│  │  │  │  │           └─ App
│  │  │  │  ├─ Flutter
│  │  │  │  ├─ Flutter.framework
│  │  │  │  │  ├─ Flutter
│  │  │  │  │  ├─ Headers
│  │  │  │  │  │  ├─ Flutter.h
│  │  │  │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │  │  │  ├─ FlutterChannels.h
│  │  │  │  │  │  ├─ FlutterCodecs.h
│  │  │  │  │  │  ├─ FlutterDartProject.h
│  │  │  │  │  │  ├─ FlutterEngine.h
│  │  │  │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │  │  │  ├─ FlutterHourFormat.h
│  │  │  │  │  │  ├─ FlutterMacros.h
│  │  │  │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │  │  │  ├─ FlutterPlugin.h
│  │  │  │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │  │  │  ├─ FlutterTexture.h
│  │  │  │  │  │  └─ FlutterViewController.h
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ Modules
│  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ icudtl.dat
│  │  │  │  ├─ Flutter.framework.dSYM
│  │  │  │  │  └─ Contents
│  │  │  │  │     ├─ Info.plist
│  │  │  │  │     └─ Resources
│  │  │  │  │        ├─ DWARF
│  │  │  │  │        │  └─ Flutter
│  │  │  │  │        └─ Relocations
│  │  │  │  │           └─ aarch64
│  │  │  │  │              └─ Flutter.yml
│  │  │  │  ├─ Pods_Runner.framework
│  │  │  │  │  ├─ Headers
│  │  │  │  │  │  └─ Pods-Runner-umbrella.h
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ Modules
│  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  └─ Pods_Runner
│  │  │  │  ├─ Runner.app
│  │  │  │  │  ├─ AppFrameworkInfo.plist
│  │  │  │  │  ├─ AppIcon60x60@2x.png
│  │  │  │  │  ├─ AppIcon76x76@2x~ipad.png
│  │  │  │  │  ├─ Assets.car
│  │  │  │  │  ├─ Base.lproj
│  │  │  │  │  │  ├─ LaunchScreen.storyboardc
│  │  │  │  │  │  │  ├─ 01J-lp-oVM-view-Ze5-6b-2t3.nib
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  └─ UIViewController-01J-lp-oVM.nib
│  │  │  │  │  │  └─ Main.storyboardc
│  │  │  │  │  │     ├─ BYZ-38-t0r-view-8bC-Xf-vdC.nib
│  │  │  │  │  │     ├─ Info.plist
│  │  │  │  │  │     └─ UIViewController-BYZ-38-t0r.nib
│  │  │  │  │  ├─ Frameworks
│  │  │  │  │  │  ├─ App.framework
│  │  │  │  │  │  │  ├─ App
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  │  │  └─ flutter_assets
│  │  │  │  │  │  │     ├─ AssetManifest.bin
│  │  │  │  │  │  │     ├─ FontManifest.json
│  │  │  │  │  │  │     ├─ NOTICES.Z
│  │  │  │  │  │  │     ├─ NativeAssetsManifest.json
│  │  │  │  │  │  │     ├─ fonts
│  │  │  │  │  │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │  │  │  │     ├─ packages
│  │  │  │  │  │  │     │  └─ cupertino_icons
│  │  │  │  │  │  │     │     └─ assets
│  │  │  │  │  │  │     │        └─ CupertinoIcons.ttf
│  │  │  │  │  │  │     └─ shaders
│  │  │  │  │  │  │        ├─ ink_sparkle.frag
│  │  │  │  │  │  │        └─ stretch_effect.frag
│  │  │  │  │  │  ├─ Flutter.framework
│  │  │  │  │  │  │  ├─ Flutter
│  │  │  │  │  │  │  ├─ Headers
│  │  │  │  │  │  │  │  ├─ Flutter.h
│  │  │  │  │  │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │  │  │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │  │  │  │  │  ├─ FlutterChannels.h
│  │  │  │  │  │  │  │  ├─ FlutterCodecs.h
│  │  │  │  │  │  │  │  ├─ FlutterDartProject.h
│  │  │  │  │  │  │  │  ├─ FlutterEngine.h
│  │  │  │  │  │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │  │  │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │  │  │  │  │  ├─ FlutterHourFormat.h
│  │  │  │  │  │  │  │  ├─ FlutterMacros.h
│  │  │  │  │  │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │  │  │  │  │  ├─ FlutterPlugin.h
│  │  │  │  │  │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │  │  │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │  │  │  │  │  ├─ FlutterTexture.h
│  │  │  │  │  │  │  │  └─ FlutterViewController.h
│  │  │  │  │  │  │  ├─ Info.plist
│  │  │  │  │  │  │  ├─ Modules
│  │  │  │  │  │  │  │  └─ module.modulemap
│  │  │  │  │  │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  │  │  └─ icudtl.dat
│  │  │  │  │  │  └─ url_launcher_ios.framework
│  │  │  │  │  │     ├─ Info.plist
│  │  │  │  │  │     ├─ _CodeSignature
│  │  │  │  │  │     │  └─ CodeResources
│  │  │  │  │  │     ├─ url_launcher_ios
│  │  │  │  │  │     └─ url_launcher_ios_privacy.bundle
│  │  │  │  │  │        ├─ Info.plist
│  │  │  │  │  │        └─ PrivacyInfo.xcprivacy
│  │  │  │  │  ├─ Info.plist
│  │  │  │  │  ├─ PkgInfo
│  │  │  │  │  ├─ Runner
│  │  │  │  │  ├─ _CodeSignature
│  │  │  │  │  │  └─ CodeResources
│  │  │  │  │  └─ embedded.mobileprovision
│  │  │  │  ├─ Runner.app.dSYM
│  │  │  │  │  └─ Contents
│  │  │  │  │     ├─ Info.plist
│  │  │  │  │     └─ Resources
│  │  │  │  │        ├─ DWARF
│  │  │  │  │        │  └─ Runner
│  │  │  │  │        └─ Relocations
│  │  │  │  │           └─ aarch64
│  │  │  │  │              └─ Runner.yml
│  │  │  │  ├─ Runner.swiftmodule
│  │  │  │  │  ├─ Project
│  │  │  │  │  │  └─ arm64-apple-ios.swiftsourceinfo
│  │  │  │  │  ├─ arm64-apple-ios.abi.json
│  │  │  │  │  ├─ arm64-apple-ios.swiftdoc
│  │  │  │  │  └─ arm64-apple-ios.swiftmodule
│  │  │  │  └─ url_launcher_ios
│  │  │  │     ├─ url_launcher_ios.framework
│  │  │  │     │  ├─ Headers
│  │  │  │     │  │  ├─ url_launcher_ios-Swift.h
│  │  │  │     │  │  └─ url_launcher_ios-umbrella.h
│  │  │  │     │  ├─ Info.plist
│  │  │  │     │  ├─ Modules
│  │  │  │     │  │  ├─ module.modulemap
│  │  │  │     │  │  └─ url_launcher_ios.swiftmodule
│  │  │  │     │  │     ├─ Project
│  │  │  │     │  │     │  └─ arm64-apple-ios.swiftsourceinfo
│  │  │  │     │  │     ├─ arm64-apple-ios.abi.json
│  │  │  │     │  │     ├─ arm64-apple-ios.swiftdoc
│  │  │  │     │  │     └─ arm64-apple-ios.swiftmodule
│  │  │  │     │  ├─ url_launcher_ios
│  │  │  │     │  └─ url_launcher_ios_privacy.bundle
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     └─ PrivacyInfo.xcprivacy
│  │  │  │     ├─ url_launcher_ios.framework.dSYM
│  │  │  │     │  └─ Contents
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     └─ Resources
│  │  │  │     │        ├─ DWARF
│  │  │  │     │        │  └─ url_launcher_ios
│  │  │  │     │        └─ Relocations
│  │  │  │     │           └─ aarch64
│  │  │  │     │              └─ url_launcher_ios.yml
│  │  │  │     └─ url_launcher_ios_privacy.bundle
│  │  │  │        ├─ Info.plist
│  │  │  │        └─ PrivacyInfo.xcprivacy
│  │  │  ├─ XCBuildData
│  │  │  │  └─ PIFCache
│  │  │  │     ├─ project
│  │  │  │     │  └─ PROJECT@v11_mod=5930724f266fb45c8839b16fe3991b79_hash=bfdfe7dc352907fc980b868725387e98plugins=1OJSG6M1FOV3XYQCBH7Z29RZ0FPR9XDE1-json
│  │  │  │     ├─ target
│  │  │  │     │  ├─ TARGET@v11_hash=159265a1bff31e9959c56f1b8acc32d9-json
│  │  │  │     │  ├─ TARGET@v11_hash=780c2dd3829ed8480b56400f7c867488-json
│  │  │  │     │  ├─ TARGET@v11_hash=83e6b9aba0176010f8d31f24567f1965-json
│  │  │  │     │  ├─ TARGET@v11_hash=ec4c5e8870eb8a14b0566b4bb98a25e6-json
│  │  │  │     │  └─ TARGET@v11_hash=fcfb37e8bd3f89501bfa877d598628a8-json
│  │  │  │     └─ workspace
│  │  │  │        └─ WORKSPACE@v11_hash=(null)_subobjects=a48dd7d1b7a40ce152fc2ce6270ee19f-json
│  │  │  ├─ app-delta
│  │  │  ├─ framework_public_headers.fingerprint
│  │  │  ├─ iphoneos
│  │  │  │  └─ Runner.app
│  │  │  │     ├─ AppFrameworkInfo.plist
│  │  │  │     ├─ AppIcon60x60@2x.png
│  │  │  │     ├─ AppIcon76x76@2x~ipad.png
│  │  │  │     ├─ Assets.car
│  │  │  │     ├─ Base.lproj
│  │  │  │     │  ├─ LaunchScreen.storyboardc
│  │  │  │     │  │  ├─ 01J-lp-oVM-view-Ze5-6b-2t3.nib
│  │  │  │     │  │  ├─ Info.plist
│  │  │  │     │  │  └─ UIViewController-01J-lp-oVM.nib
│  │  │  │     │  └─ Main.storyboardc
│  │  │  │     │     ├─ BYZ-38-t0r-view-8bC-Xf-vdC.nib
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     └─ UIViewController-BYZ-38-t0r.nib
│  │  │  │     ├─ Frameworks
│  │  │  │     │  ├─ App.framework
│  │  │  │     │  │  ├─ App
│  │  │  │     │  │  ├─ Info.plist
│  │  │  │     │  │  ├─ _CodeSignature
│  │  │  │     │  │  │  └─ CodeResources
│  │  │  │     │  │  └─ flutter_assets
│  │  │  │     │  │     ├─ AssetManifest.bin
│  │  │  │     │  │     ├─ FontManifest.json
│  │  │  │     │  │     ├─ NOTICES.Z
│  │  │  │     │  │     ├─ NativeAssetsManifest.json
│  │  │  │     │  │     ├─ fonts
│  │  │  │     │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │     │  │     ├─ packages
│  │  │  │     │  │     │  └─ cupertino_icons
│  │  │  │     │  │     │     └─ assets
│  │  │  │     │  │     │        └─ CupertinoIcons.ttf
│  │  │  │     │  │     └─ shaders
│  │  │  │     │  │        ├─ ink_sparkle.frag
│  │  │  │     │  │        └─ stretch_effect.frag
│  │  │  │     │  ├─ Flutter.framework
│  │  │  │     │  │  ├─ Flutter
│  │  │  │     │  │  ├─ Headers
│  │  │  │     │  │  │  ├─ Flutter.h
│  │  │  │     │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │     │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │     │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │     │  │  │  ├─ FlutterChannels.h
│  │  │  │     │  │  │  ├─ FlutterCodecs.h
│  │  │  │     │  │  │  ├─ FlutterDartProject.h
│  │  │  │     │  │  │  ├─ FlutterEngine.h
│  │  │  │     │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │     │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │     │  │  │  ├─ FlutterHourFormat.h
│  │  │  │     │  │  │  ├─ FlutterMacros.h
│  │  │  │     │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │     │  │  │  ├─ FlutterPlugin.h
│  │  │  │     │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │     │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │     │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │     │  │  │  ├─ FlutterTexture.h
│  │  │  │     │  │  │  └─ FlutterViewController.h
│  │  │  │     │  │  ├─ Info.plist
│  │  │  │     │  │  ├─ Modules
│  │  │  │     │  │  │  └─ module.modulemap
│  │  │  │     │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │     │  │  ├─ _CodeSignature
│  │  │  │     │  │  │  └─ CodeResources
│  │  │  │     │  │  └─ icudtl.dat
│  │  │  │     │  └─ url_launcher_ios.framework
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     ├─ _CodeSignature
│  │  │  │     │     │  └─ CodeResources
│  │  │  │     │     ├─ url_launcher_ios
│  │  │  │     │     └─ url_launcher_ios_privacy.bundle
│  │  │  │     │        ├─ Info.plist
│  │  │  │     │        └─ PrivacyInfo.xcprivacy
│  │  │  │     ├─ Info.plist
│  │  │  │     ├─ PkgInfo
│  │  │  │     ├─ Runner
│  │  │  │     ├─ _CodeSignature
│  │  │  │     │  └─ CodeResources
│  │  │  │     └─ embedded.mobileprovision
│  │  │  ├─ iphonesimulator
│  │  │  │  └─ Runner.app
│  │  │  │     ├─ AppFrameworkInfo.plist
│  │  │  │     ├─ AppIcon60x60@2x.png
│  │  │  │     ├─ AppIcon76x76@2x~ipad.png
│  │  │  │     ├─ Assets.car
│  │  │  │     ├─ Base.lproj
│  │  │  │     │  ├─ LaunchScreen.storyboardc
│  │  │  │     │  │  ├─ 01J-lp-oVM-view-Ze5-6b-2t3.nib
│  │  │  │     │  │  ├─ Info.plist
│  │  │  │     │  │  └─ UIViewController-01J-lp-oVM.nib
│  │  │  │     │  └─ Main.storyboardc
│  │  │  │     │     ├─ BYZ-38-t0r-view-8bC-Xf-vdC.nib
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     └─ UIViewController-BYZ-38-t0r.nib
│  │  │  │     ├─ Frameworks
│  │  │  │     │  ├─ App.framework
│  │  │  │     │  │  ├─ App
│  │  │  │     │  │  ├─ Info.plist
│  │  │  │     │  │  ├─ _CodeSignature
│  │  │  │     │  │  │  └─ CodeResources
│  │  │  │     │  │  └─ flutter_assets
│  │  │  │     │  │     ├─ AssetManifest.bin
│  │  │  │     │  │     ├─ FontManifest.json
│  │  │  │     │  │     ├─ NOTICES.Z
│  │  │  │     │  │     ├─ NativeAssetsManifest.json
│  │  │  │     │  │     ├─ fonts
│  │  │  │     │  │     │  └─ MaterialIcons-Regular.otf
│  │  │  │     │  │     ├─ isolate_snapshot_data
│  │  │  │     │  │     ├─ kernel_blob.bin
│  │  │  │     │  │     ├─ packages
│  │  │  │     │  │     │  └─ cupertino_icons
│  │  │  │     │  │     │     └─ assets
│  │  │  │     │  │     │        └─ CupertinoIcons.ttf
│  │  │  │     │  │     ├─ shaders
│  │  │  │     │  │     │  ├─ ink_sparkle.frag
│  │  │  │     │  │     │  └─ stretch_effect.frag
│  │  │  │     │  │     └─ vm_snapshot_data
│  │  │  │     │  ├─ Flutter.framework
│  │  │  │     │  │  ├─ Flutter
│  │  │  │     │  │  ├─ Headers
│  │  │  │     │  │  │  ├─ Flutter.h
│  │  │  │     │  │  │  ├─ FlutterAppDelegate.h
│  │  │  │     │  │  │  ├─ FlutterBinaryMessenger.h
│  │  │  │     │  │  │  ├─ FlutterCallbackCache.h
│  │  │  │     │  │  │  ├─ FlutterChannels.h
│  │  │  │     │  │  │  ├─ FlutterCodecs.h
│  │  │  │     │  │  │  ├─ FlutterDartProject.h
│  │  │  │     │  │  │  ├─ FlutterEngine.h
│  │  │  │     │  │  │  ├─ FlutterEngineGroup.h
│  │  │  │     │  │  │  ├─ FlutterHeadlessDartRunner.h
│  │  │  │     │  │  │  ├─ FlutterHourFormat.h
│  │  │  │     │  │  │  ├─ FlutterMacros.h
│  │  │  │     │  │  │  ├─ FlutterPlatformViews.h
│  │  │  │     │  │  │  ├─ FlutterPlugin.h
│  │  │  │     │  │  │  ├─ FlutterPluginAppLifeCycleDelegate.h
│  │  │  │     │  │  │  ├─ FlutterSceneDelegate.h
│  │  │  │     │  │  │  ├─ FlutterSceneLifeCycle.h
│  │  │  │     │  │  │  ├─ FlutterTexture.h
│  │  │  │     │  │  │  └─ FlutterViewController.h
│  │  │  │     │  │  ├─ Info.plist
│  │  │  │     │  │  ├─ Modules
│  │  │  │     │  │  │  └─ module.modulemap
│  │  │  │     │  │  ├─ PrivacyInfo.xcprivacy
│  │  │  │     │  │  ├─ _CodeSignature
│  │  │  │     │  │  │  └─ CodeResources
│  │  │  │     │  │  └─ icudtl.dat
│  │  │  │     │  └─ url_launcher_ios.framework
│  │  │  │     │     ├─ Info.plist
│  │  │  │     │     ├─ _CodeSignature
│  │  │  │     │     │  └─ CodeResources
│  │  │  │     │     ├─ url_launcher_ios
│  │  │  │     │     └─ url_launcher_ios_privacy.bundle
│  │  │  │     │        ├─ Info.plist
│  │  │  │     │        └─ PrivacyInfo.xcprivacy
│  │  │  │     ├─ Info.plist
│  │  │  │     ├─ PkgInfo
│  │  │  │     ├─ Runner
│  │  │  │     ├─ Runner.debug.dylib
│  │  │  │     ├─ _CodeSignature
│  │  │  │     │  └─ CodeResources
│  │  │  │     └─ __preview.dylib
│  │  │  └─ pod_inputs.fingerprint
│  │  ├─ native_assets
│  │  │  └─ ios
│  │  └─ native_hooks
│  │     └─ .last_build_id
│  ├─ flutter_app.iml
│  ├─ ios
│  │  ├─ .symlinks
│  │  │  └─ plugins
│  │  │     └─ url_launcher_ios
│  │  │        ├─ AUTHORS
│  │  │        ├─ CHANGELOG.md
│  │  │        ├─ LICENSE
│  │  │        ├─ README.md
│  │  │        ├─ example
│  │  │        │  ├─ README.md
│  │  │        │  ├─ integration_test
│  │  │        │  │  └─ url_launcher_test.dart
│  │  │        │  ├─ ios
│  │  │        │  │  ├─ Flutter
│  │  │        │  │  │  ├─ AppFrameworkInfo.plist
│  │  │        │  │  │  ├─ Debug.xcconfig
│  │  │        │  │  │  └─ Release.xcconfig
│  │  │        │  │  ├─ Podfile
│  │  │        │  │  ├─ Runner
│  │  │        │  │  │  ├─ AppDelegate.swift
│  │  │        │  │  │  ├─ Assets.xcassets
│  │  │        │  │  │  │  ├─ AppIcon.appiconset
│  │  │        │  │  │  │  │  ├─ Contents.json
│  │  │        │  │  │  │  │  ├─ Icon-App-1024x1024@1x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-20x20@1x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-20x20@2x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-20x20@3x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-29x29@1x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-29x29@2x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-29x29@3x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-40x40@1x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-40x40@2x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-40x40@3x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-60x60@2x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-60x60@3x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-76x76@1x.png
│  │  │        │  │  │  │  │  ├─ Icon-App-76x76@2x.png
│  │  │        │  │  │  │  │  └─ Icon-App-83.5x83.5@2x.png
│  │  │        │  │  │  │  └─ LaunchImage.imageset
│  │  │        │  │  │  │     ├─ Contents.json
│  │  │        │  │  │  │     ├─ LaunchImage.png
│  │  │        │  │  │  │     ├─ LaunchImage@2x.png
│  │  │        │  │  │  │     └─ LaunchImage@3x.png
│  │  │        │  │  │  ├─ Base.lproj
│  │  │        │  │  │  │  ├─ LaunchScreen.storyboard
│  │  │        │  │  │  │  └─ Main.storyboard
│  │  │        │  │  │  ├─ Info.plist
│  │  │        │  │  │  ├─ Runner-Bridging-Header.h
│  │  │        │  │  │  └─ SceneDelegate.swift
│  │  │        │  │  ├─ Runner.xcodeproj
│  │  │        │  │  │  ├─ project.pbxproj
│  │  │        │  │  │  ├─ project.xcworkspace
│  │  │        │  │  │  │  ├─ contents.xcworkspacedata
│  │  │        │  │  │  │  └─ xcshareddata
│  │  │        │  │  │  │     ├─ IDEWorkspaceChecks.plist
│  │  │        │  │  │  │     └─ WorkspaceSettings.xcsettings
│  │  │        │  │  │  └─ xcshareddata
│  │  │        │  │  │     └─ xcschemes
│  │  │        │  │  │        └─ Runner.xcscheme
│  │  │        │  │  ├─ Runner.xcworkspace
│  │  │        │  │  │  ├─ contents.xcworkspacedata
│  │  │        │  │  │  └─ xcshareddata
│  │  │        │  │  │     ├─ IDEWorkspaceChecks.plist
│  │  │        │  │  │     └─ WorkspaceSettings.xcsettings
│  │  │        │  │  ├─ RunnerTests
│  │  │        │  │  │  └─ URLLauncherTests.swift
│  │  │        │  │  └─ RunnerUITests
│  │  │        │  │     └─ URLLauncherUITests.swift
│  │  │        │  ├─ lib
│  │  │        │  │  └─ main.dart
│  │  │        │  ├─ pubspec.yaml
│  │  │        │  └─ test_driver
│  │  │        │     └─ integration_test.dart
│  │  │        ├─ ios
│  │  │        │  ├─ Assets
│  │  │        │  ├─ url_launcher_ios
│  │  │        │  │  ├─ Package.swift
│  │  │        │  │  └─ Sources
│  │  │        │  │     └─ url_launcher_ios
│  │  │        │  │        ├─ Launcher.swift
│  │  │        │  │        ├─ Resources
│  │  │        │  │        │  └─ PrivacyInfo.xcprivacy
│  │  │        │  │        ├─ URLLaunchSession.swift
│  │  │        │  │        ├─ URLLauncherPlugin.swift
│  │  │        │  │        ├─ ViewPresenter.swift
│  │  │        │  │        └─ messages.g.swift
│  │  │        │  └─ url_launcher_ios.podspec
│  │  │        ├─ lib
│  │  │        │  ├─ src
│  │  │        │  │  └─ messages.g.dart
│  │  │        │  └─ url_launcher_ios.dart
│  │  │        ├─ pigeons
│  │  │        │  ├─ copyright.txt
│  │  │        │  └─ messages.dart
│  │  │        ├─ pubspec.yaml
│  │  │        └─ test
│  │  │           ├─ url_launcher_ios_test.dart
│  │  │           └─ url_launcher_ios_test.mocks.dart
│  │  ├─ Flutter
│  │  │  ├─ AppFrameworkInfo.plist
│  │  │  ├─ Debug.xcconfig
│  │  │  ├─ Flutter.podspec
│  │  │  ├─ Generated.xcconfig
│  │  │  ├─ Release.xcconfig
│  │  │  ├─ ephemeral
│  │  │  │  ├─ flutter_lldb_helper.py
│  │  │  │  └─ flutter_lldbinit
│  │  │  └─ flutter_export_environment.sh
│  │  ├─ Podfile
│  │  ├─ Podfile.lock
│  │  ├─ Pods
│  │  │  ├─ Headers
│  │  │  ├─ Local Podspecs
│  │  │  │  ├─ Flutter.podspec.json
│  │  │  │  └─ url_launcher_ios.podspec.json
│  │  │  ├─ Manifest.lock
│  │  │  ├─ Pods.xcodeproj
│  │  │  │  ├─ project.pbxproj
│  │  │  │  └─ xcuserdata
│  │  │  │     └─ artemijsmykov.xcuserdatad
│  │  │  │        └─ xcschemes
│  │  │  │           ├─ Flutter.xcscheme
│  │  │  │           ├─ Pods-Runner.xcscheme
│  │  │  │           ├─ Pods-RunnerTests.xcscheme
│  │  │  │           ├─ url_launcher_ios-url_launcher_ios_privacy.xcscheme
│  │  │  │           ├─ url_launcher_ios.xcscheme
│  │  │  │           └─ xcschememanagement.plist
│  │  │  └─ Target Support Files
│  │  │     ├─ Flutter
│  │  │     │  ├─ Flutter.debug.xcconfig
│  │  │     │  └─ Flutter.release.xcconfig
│  │  │     ├─ Pods-Runner
│  │  │     │  ├─ Pods-Runner-Info.plist
│  │  │     │  ├─ Pods-Runner-acknowledgements.markdown
│  │  │     │  ├─ Pods-Runner-acknowledgements.plist
│  │  │     │  ├─ Pods-Runner-dummy.m
│  │  │     │  ├─ Pods-Runner-frameworks-Debug-input-files.xcfilelist
│  │  │     │  ├─ Pods-Runner-frameworks-Debug-output-files.xcfilelist
│  │  │     │  ├─ Pods-Runner-frameworks-Profile-input-files.xcfilelist
│  │  │     │  ├─ Pods-Runner-frameworks-Profile-output-files.xcfilelist
│  │  │     │  ├─ Pods-Runner-frameworks-Release-input-files.xcfilelist
│  │  │     │  ├─ Pods-Runner-frameworks-Release-output-files.xcfilelist
│  │  │     │  ├─ Pods-Runner-frameworks.sh
│  │  │     │  ├─ Pods-Runner-umbrella.h
│  │  │     │  ├─ Pods-Runner.debug.xcconfig
│  │  │     │  ├─ Pods-Runner.modulemap
│  │  │     │  ├─ Pods-Runner.profile.xcconfig
│  │  │     │  └─ Pods-Runner.release.xcconfig
│  │  │     ├─ Pods-RunnerTests
│  │  │     │  ├─ Pods-RunnerTests-Info.plist
│  │  │     │  ├─ Pods-RunnerTests-acknowledgements.markdown
│  │  │     │  ├─ Pods-RunnerTests-acknowledgements.plist
│  │  │     │  ├─ Pods-RunnerTests-dummy.m
│  │  │     │  ├─ Pods-RunnerTests-umbrella.h
│  │  │     │  ├─ Pods-RunnerTests.debug.xcconfig
│  │  │     │  ├─ Pods-RunnerTests.modulemap
│  │  │     │  ├─ Pods-RunnerTests.profile.xcconfig
│  │  │     │  └─ Pods-RunnerTests.release.xcconfig
│  │  │     └─ url_launcher_ios
│  │  │        ├─ ResourceBundle-url_launcher_ios_privacy-url_launcher_ios-Info.plist
│  │  │        ├─ url_launcher_ios-Info.plist
│  │  │        ├─ url_launcher_ios-dummy.m
│  │  │        ├─ url_launcher_ios-prefix.pch
│  │  │        ├─ url_launcher_ios-umbrella.h
│  │  │        ├─ url_launcher_ios.debug.xcconfig
│  │  │        ├─ url_launcher_ios.modulemap
│  │  │        └─ url_launcher_ios.release.xcconfig
│  │  ├─ Runner
│  │  │  ├─ AppDelegate.swift
│  │  │  ├─ Assets.xcassets
│  │  │  │  ├─ AppIcon.appiconset
│  │  │  │  │  ├─ Contents.json
│  │  │  │  │  ├─ Icon-App-1024x1024@1x.png
│  │  │  │  │  ├─ Icon-App-20x20@1x.png
│  │  │  │  │  ├─ Icon-App-20x20@2x.png
│  │  │  │  │  ├─ Icon-App-20x20@3x.png
│  │  │  │  │  ├─ Icon-App-29x29@1x.png
│  │  │  │  │  ├─ Icon-App-29x29@2x.png
│  │  │  │  │  ├─ Icon-App-29x29@3x.png
│  │  │  │  │  ├─ Icon-App-40x40@1x.png
│  │  │  │  │  ├─ Icon-App-40x40@2x.png
│  │  │  │  │  ├─ Icon-App-40x40@3x.png
│  │  │  │  │  ├─ Icon-App-50x50@1x.png
│  │  │  │  │  ├─ Icon-App-50x50@2x.png
│  │  │  │  │  ├─ Icon-App-57x57@1x.png
│  │  │  │  │  ├─ Icon-App-57x57@2x.png
│  │  │  │  │  ├─ Icon-App-60x60@2x.png
│  │  │  │  │  ├─ Icon-App-60x60@3x.png
│  │  │  │  │  ├─ Icon-App-72x72@1x.png
│  │  │  │  │  ├─ Icon-App-72x72@2x.png
│  │  │  │  │  ├─ Icon-App-76x76@1x.png
│  │  │  │  │  ├─ Icon-App-76x76@2x.png
│  │  │  │  │  └─ Icon-App-83.5x83.5@2x.png
│  │  │  │  └─ LaunchImage.imageset
│  │  │  │     ├─ Contents.json
│  │  │  │     ├─ LaunchImage.png
│  │  │  │     ├─ LaunchImage@2x.png
│  │  │  │     ├─ LaunchImage@3x.png
│  │  │  │     └─ README.md
│  │  │  ├─ Base.lproj
│  │  │  │  ├─ LaunchScreen.storyboard
│  │  │  │  └─ Main.storyboard
│  │  │  ├─ GeneratedPluginRegistrant.h
│  │  │  ├─ GeneratedPluginRegistrant.m
│  │  │  ├─ Info.plist
│  │  │  ├─ Runner-Bridging-Header.h
│  │  │  └─ SceneDelegate.swift
│  │  ├─ Runner.xcodeproj
│  │  │  ├─ project.pbxproj
│  │  │  ├─ project.xcworkspace
│  │  │  │  ├─ contents.xcworkspacedata
│  │  │  │  └─ xcshareddata
│  │  │  │     ├─ IDEWorkspaceChecks.plist
│  │  │  │     ├─ WorkspaceSettings.xcsettings
│  │  │  │     └─ swiftpm
│  │  │  │        └─ configuration
│  │  │  └─ xcshareddata
│  │  │     └─ xcschemes
│  │  │        └─ Runner.xcscheme
│  │  ├─ Runner.xcworkspace
│  │  │  ├─ contents.xcworkspacedata
│  │  │  ├─ xcshareddata
│  │  │  │  ├─ IDEWorkspaceChecks.plist
│  │  │  │  ├─ WorkspaceSettings.xcsettings
│  │  │  │  └─ swiftpm
│  │  │  │     └─ configuration
│  │  │  └─ xcuserdata
│  │  │     └─ artemijsmykov.xcuserdatad
│  │  │        └─ UserInterfaceState.xcuserstate
│  │  └─ RunnerTests
│  │     └─ RunnerTests.swift
│  ├─ lib
│  │  ├─ core
│  │  │  ├─ api
│  │  │  │  └─ api_client.dart
│  │  │  └─ models
│  │  │     ├─ analysis_result.dart
│  │  │     ├─ domain_stats.dart
│  │  │     ├─ feed_item.dart
│  │  │     └─ history_item.dart
│  │  ├─ features
│  │  │  ├─ analysis
│  │  │  │  ├─ providers
│  │  │  │  │  └─ analysis_provider.dart
│  │  │  │  ├─ screens
│  │  │  │  │  ├─ analysis_screen.dart
│  │  │  │  │  └─ history_screen.dart
│  │  │  │  └─ widgets
│  │  │  │     └─ verdict_card.dart
│  │  │  ├─ feed
│  │  │  │  └─ screens
│  │  │  │     ├─ feed_screen.dart
│  │  │  │     └─ news_detail_screen.dart
│  │  │  ├─ graph
│  │  │  │  └─ screens
│  │  │  │     └─ graph_screen.dart
│  │  │  └─ sources
│  │  │     └─ screens
│  │  │        ├─ domain_stats_screen.dart
│  │  │        └─ sources_screen.dart
│  │  ├─ main.dart
│  │  └─ shared
│  │     └─ theme
│  ├─ pubspec.lock
│  ├─ pubspec.yaml
│  └─ test
│     └─ widget_test.dart
└─ requirements.txt

```