# Wave 0 — выполнено

## Собрано

| Компонент | Путь |
|-----------|------|
| Android phone | `apps/phone-android/` |
| HarmonyOS watch | `apps/watch-harmony/` |
| Version catalog | `gradle/libs.versions.toml` |

## Сборка телефона

```bash
cd fit-huawei/apps/phone-android
./gradlew :app:assembleDebug :app:testDebugUnitTest
```

APK: `app/build/outputs/apk/debug/app-debug.apk`

### HMS (реальный OAuth на EMUI)

1. AppGallery Connect → приложение `com.chairup.android` → Health Kit  
2. Скачать `agconnect-services.json` → `app/agconnect-services.json`  
3. Пересобрать — `BuildConfig.HMS_ENABLED=true`, подключится `HmsHealthGateway`

Без файла: **stub** — кнопка открывает HUAWEI Health.

## Сборка часов

1. DevEco Studio 5+ → Open `apps/watch-harmony`  
2. Подключить часы HarmonyOS → Run `entry`  
3. HAP: `entry/build/default/outputs/default/entry-default-signed.hap`

## Критерии Wave 0

- [x] Compose + Navigation (3 вкладки)  
- [x] Hilt + Room  
- [x] Тема «Кресло» `#0B0F14` / `#00D9A5`  
- [x] Экран HUAWEI Health  
- [x] HMS опционально через `agconnect-services.json`  
- [x] Watch: Index + таймер 2 мин (UI)  
- [x] Unit test DailyScore  

## Дальше — Wave 1

Чтение шагов/сна из HMS, дашборд 7 дней.
