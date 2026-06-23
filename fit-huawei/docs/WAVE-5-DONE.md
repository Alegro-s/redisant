# Wave 5 — Умный коуч

**Версия:** `0.9.0-wave5`  
**Статус:** готово

## Что сделано

### Coach Engine YAML
- `assets/coach/neat-v1.yaml` — правила из `shared/coach/rules/`
- `CoachEngine` — парсер + evaluate
- `CoachRulesWorker` — YAML-driven уведомления

### Правила
- `sedentary_nudge` — шаги за 45 мин < 80
- `afternoon_catchup` — после 15:00, < 4 микро
- `protein_evening` — после 19:00, белок < 60%
- `celebrate_micro_complete` — 8/8 микро

### DND и лимит пушей
- «Не беси» 22:00–08:00
- Макс 6 пушей/день (`tryConsumeDailyNudge`)
- `WaistReminderWorker` уважает лимит

### Недельный отчёт
- `CoachRepository.observeWeeklyReport()`
- UI: `WeeklyReportScreen` + карточка на «Сегодня»

### Адаптация шагов
- +500 за каждую успешную неделю (≥5 дней score 70+)
- Персистентно в DataStore (`stepBonusWeeks`)

### Часы — Form widget
- `MicroDotsForm.ets` — 8 точек на циферблате
- `MicroDotsFormAbility` + `form_config.json`

## Тесты

`CoachEngineTest` — sedentary + protein rules

## Дальше — Wave 6

Локализация, privacy, JSON backup, release.
