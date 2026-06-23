# ChairUp — фитнес-коуч для «кресла» (Huawei EMUI + HarmonyOS)

Мобильное приложение + приложение на часах: сброс жира, рост мышц, NEAT-трекинг для сидячего образа жизни. Данные — из **HUAWEI Health** и сенсоров часов.

## Документация

| Файл | Содержание |
|------|------------|
| [docs/01-architecture.md](docs/01-architecture.md) | Системная архитектура, слои, модули, диаграммы |
| [docs/02-huawei-ecosystem.md](docs/02-huawei-ecosystem.md) | HMS Health Kit, часы, синк, ограничения |
| [docs/03-mvp-waves.md](docs/03-mvp-waves.md) | MVP по волнам (0→6), критерии готовности |
| [docs/04-data-model.md](docs/04-data-model.md) | Схема данных, события, метрики |
| [docs/05-ux-flows.md](docs/05-ux-flows.md) | Экраны, сценарии, «ленивый» UX |
| [docs/06-tech-stack.md](docs/06-tech-stack.md) | Стек, репозитории, CI, публикация |

## Целевой профиль (v1)

- Телефон: **Huawei EMUI** (Android + HMS Core)
- Часы: **HarmonyOS Wearable** (Watch 3/4/5, GT, Fit и т.п.)
- Пользователь: ~88 кг, цель — меньше жира, больше мышц, мало движения вне зала

## Статус: Wave 6 ✅ (MVP Store-ready)

Все волны 0→6 выполнены.  
[docs/WAVE-6-DONE.md](docs/WAVE-6-DONE.md) · [docs/WAVE-5-DONE.md](docs/WAVE-5-DONE.md) · [docs/WAVE-4.5-DONE.md](docs/WAVE-4.5-DONE.md)

## Структура кода

```
fit-huawei/
├── apps/
│   ├── phone-android/      # Kotlin + Compose + Hilt + Room (собирается)
│   └── watch-harmony/      # ArkTS — открыть в DevEco Studio
├── shared/
│   ├── contracts/          # wear-messages.schema.json
│   └── coach/rules/        # neat-v1.yaml
└── docs/
```

## Быстрый старт — телефон

```powershell
.\fit-huawei\scripts\setup-android-dev.ps1
cd fit-huawei\apps\phone-android
$env:JAVA_HOME = "$env:LOCALAPPDATA\Programs\Android Studio\jbr"
.\gradlew.bat :app:assembleDebug
adb install -r app\build\outputs\apk\debug\app-debug.apk
```

## Быстрый старт — часы

DevEco Studio → Open `apps/watch-harmony` → Run on wearable.

## HMS (Wave 0+)

1. Зарегистрировать приложение в [AppGallery Connect](https://developer.huawei.com/consumer/en/service/josp/agc/index.html)
2. Включить **Health Kit** и **Wear Engine** (если доступен для модели часов)
3. Собрать `phone-android`, выдать разрешения HUAWEI Health
4. Установить `watch-harmony` через DevEco Studio → Deploy to device

---

*Проектирование — май 2026. Не медицинское ПО; перед диетой/нагрузкой — врач при хронических заболеваниях.*
