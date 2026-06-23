# ChairUp — Phone (EMUI / HMS)

**Статус:** Wave 0 ✅ — debug APK собирается.

## Сборка

```powershell
$env:JAVA_HOME = "$env:LOCALAPPDATA\Programs\Android Studio\jbr"  # JDK 17–21
copy local.properties.example local.properties  # укажите sdk.dir
.\gradlew.bat :app:assembleDebug :app:testDebugUnitTest
```

APK: `app/build/outputs/apk/debug/app-debug.apk`

## HMS Health Kit

1. AppGallery Connect → `com.chairup.android` → Health Kit  
2. `agconnect-services.json` → `app/`  
3. Пересборка подхватит `src/hms/` и `HmsHealthGateway`

Без json: **stub** — вкладка Health открывает приложение HUAWEI Health.

См. [docs/WAVE-0-DONE.md](../../docs/WAVE-0-DONE.md).
