# Wave 3 — Тело (белок, вес, талия)

**Версия:** `0.4.0-wave3`  
**Статус:** готово

## Что сделано

### Данные (Room v4)
- Таблицы `weight_entry`, `waist_entry`
- Поле `proteinG` в `daily_aggregate` (уже было в схеме)
- Миграция `MIGRATION_3_4`

### Домен
- `ProteinPresets` — быстрые кнопки (+18…+35 г), цель ~1.8× вес
- `WeightTrend` — MA7, `trendRatio` для daily score
- `DailyScoreCalculator` v3: **40%** микро · **25%** шаги · **25%** белок · **10%** тренд веса

### Репозитории
- `NutritionRepository` — белок, вес, талия, UI state
- `MicroRepository` — пересчёт score с белком и трендом
- Стартовый вес **88 кг** при первом запуске

### UI
- Вкладка **«Тело»** (`BodyScreen`) — пресеты белка, «как вчера», вес + график MA7, талия
- **Сегодня** — карточка белка в статистике, подпись Wave 3

### Фон
- `WaistReminderWorker` — раз в сутки, напоминание если талия не мерилась ≥14 дней (с учётом DND)

## Сборка

```powershell
cd d:\PO\fit-huawei\apps\phone-android
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
.\gradlew :app:assembleDebug :app:testDebugUnitTest
```

APK: `app/build/outputs/apk/debug/app-debug.apk`

## Дальше

См. [WAVE-4-DONE.md](WAVE-4-DONE.md) — силовые шаблоны A/B.
