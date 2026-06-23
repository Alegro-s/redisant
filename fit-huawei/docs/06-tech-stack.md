# Технологический стек

## Сводка

| Слой | Технология |
|------|------------|
| Phone | Kotlin 2.x, Jetpack Compose, Material 3 |
| DI | Hilt |
| DB | Room |
| Async | Coroutines + Flow |
| Background | WorkManager |
| Health | HMS Health Kit 6.x |
| Wear link | Wear Engine Kit (phone) |
| Watch | ArkTS, ArkUI, Stage Model API 9+ |
| Watch IDE | DevEco Studio 5.0+ |
| Analytics | HMS Analytics (opt-in) |
| Crash | AppGallery Crash Service |

## Версии (зафиксировать в catalog)

```toml
# gradle/libs.versions.toml (план)
kotlin = "2.0.21"
compose-bom = "2024.10.00"
hilt = "2.52"
room = "2.6.1"
hms-health = "6.12.0.300"  # проверить на developer.huawei.com
```

## Сборка

```bash
# Phone
cd apps/phone-android
./gradlew :app:assembleDebug

# Watch — DevEco GUI или
hvigorw assembleHap -p product=default
```

## CI (GitHub Actions)

```yaml
# .github/workflows/fit-huawei-phone.yml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '17' }
      - run: cd fit-huawei/apps/phone-android && ./gradlew lint test assembleDebug
```

Watch HAP — локально (нужен SDK Huawei).

## Секреты

```
fit-huawei/
  local.properties          # gitignore
  phone-android/app/agconnect-services.json  # gitignore
```

Шаблон: `agconnect-services.json.example`

## Тестирование

| Уровень | Что |
|---------|-----|
| Unit | Coach rules, DailyScore calc |
| Android instrumented | Room DAO |
| Manual | HMS на реальном Mate/Pura + Watch GT |

## Пакеты

- Phone: `com.chairup.android`  
- Watch: `com.chairup.watch`  
