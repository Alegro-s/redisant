# Wave 6 — Полировка + релиз

**Версия:** `1.0.0-wave6`  
**Статус:** готово (Store-ready scaffold)

## Что сделано

### Локализация
- `values-en/strings.xml` (app name, widget)
- Watch: `resources/en_US/element/string.json`

### Privacy
- `PrivacyScreen` — Health Kit disclosure, локальное хранение, Wear Engine

### Backup JSON
- `BackupExporter` — экспорт Room → JSON
- Settings → «Экспорт JSON в Files» (SAF)

### Release
- `versionName 1.0.0-wave6`, `versionCode 7`
- Release: minify + shrinkResources
- HMS Wear Engine dependency
- `CoachEngineTest` + unit tests

### Beta checklist
1. AppGallery Connect → internal track
2. `agconnect-services.json` + Health Kit + Wear Engine
3. 10 тестеров, 7 дней crash-free
4. Pre-launch report в AppGallery

## Сборка release

```powershell
cd fit-huawei\apps\phone-android
.\gradlew :app:assembleRelease :app:testDebugUnitTest
```

APK: `app/build/outputs/apk/release/app-release.apk`

## Метрики приёмки Wave 6

- Crash-free ≥ 99.5% (7 дней беты)
- Экспорт JSON < 2 с на типичном профиле
- Отчёт генерируется локально < 500 ms
