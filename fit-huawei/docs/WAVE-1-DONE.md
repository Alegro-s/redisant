# Wave 1 — «Вижу себя» ✅

## Реализовано

- Чтение из **HMS Health Kit**: шаги (сегодня + 7 дней), сон, пульс в покое
- **Pull-to-refresh** на экране «Сегодня»
- **Кэш Room** (`health_day`) — офлайн показывает вчерашние данные
- **Онбординг** 3 шага: Health → батарея EMUI → часы
- Экран Health: OAuth + энергосбережение + настройки приложения

## Сборка (исправления инфраструктуры)

- `settings.gradle.kts` — авто `local.properties` из `ANDROID_HOME`
- Gradle **Java toolchain 17** + foojay resolver (не ломается на Java 26)
- HMS **всегда в зависимостях**; `agconnect-services.json` → `HMS_ENABLED=true`
- `scripts/setup-android-dev.ps1` — одна команда для SDK/JDK

```powershell
.\fit-huawei\scripts\setup-android-dev.ps1
cd fit-huawei\apps\phone-android
$env:JAVA_HOME = "$env:LOCALAPPDATA\Programs\Android Studio\jbr"
.\gradlew.bat :app:assembleDebug
```

## На Huawei

1. Положить `agconnect-services.json` в `app/`
2. Собрать APK, установить
3. Онбординг → Подключить Health → потянуть экран вниз на «Сегодня»

## Дальше — Wave 2

Режим «Кресло», 8 микро-слотов, Wear Engine.
