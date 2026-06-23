# Wave 4 — Силовая «ленивец»

**Версия:** `0.5.0-wave4`  
**Статус:** готово (телефон + таймер отдыха на часах)

## Что сделано

### Шаблоны A / B
- **A:** отжимания, присед, планка (~25 мин)
- **B:** выпады, тяга резиной, ягодичный мост (~30 мин)
- Прогрессия: **+1 повт/нед** (секунды для планки)

### Тренировка
- Чекбоксы подходов (3× на упражнение)
- Таймер отдыха **60 с** после каждого подхода
- Завершение → `strength_workout` в Room, `strengthDone` в daily aggregate

### Score v4
40% микро · 20% шаги · 20% белок · 10% вес · **10% силовая**

### UI
- Вкладка **«Сила»**
- Экран тренировки с отдыхом
- На **Сегодня** — кнопка «Сила 1/2»

### Часы (HarmonyOS)
- `StrengthRest.ets` — 60 с + вибрация
- Кнопка на главном экране часов

### Заглушки (Wave 4.5)
- Импорт workout из HUAWEI Health (`tryImportFromHealth`)
- Wear Engine синк phone↔watch

## Сборка

```powershell
$env:JAVA_HOME = "C:\Users\igor-\AppData\Local\Programs\Android Studio\jbr"
cd d:\PO\fit-huawei\apps\phone-android
.\gradlew :app:assembleDebug :app:testDebugUnitTest
```

## Дальше — Wave 5

Coach YAML, DND пушей, недельный отчёт, адаптация шагов.
