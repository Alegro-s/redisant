# Wave 2 — «Кресло» + микро-сессии ✅

## Реализовано

| Функция | Статус |
|---------|--------|
| Toggle «Режим Кресло» | DataStore + UI |
| 4→8 слотов по неделям | `WaveProgression` |
| Таймер 2 мин на телефоне | `MicroTimerScreen` |
| Таймер на часах | `MicroTimer.ets` (DevEco) |
| Daily Score v1 | 55% микро + 45% шаги |
| Пуши EMUI | `ChairNudgeWorker` каждые 15 мин |
| Виджет 2×2 | `ChairUpWidgetProvider` |
| DND 22–08 | Настройки |

## Сборка

```powershell
$env:JAVA_HOME = "$env:LOCALAPPDATA\Programs\Android Studio\jbr"
cd fit-huawei\apps\phone-android
.\gradlew.bat :app:assembleDebug
```

Версия: **0.3.0-wave2**

## Как пользоваться

1. «Сегодня» → включить **Режим «Кресло»**
2. Нажать **▶ 2 минуты** или слот по времени (10:00…)
3. Пройти 2 мин → **Готово** (минимум 60 сек)
4. Score и виджет обновятся

## Wear Engine

Синк часов → телефон — **Wave 2.5** (нужен Wear Engine Kit на вашей модели).  
Пока микро на часах — отдельный таймер; на телефоне засчитывается вручную.

## Дальше — Wave 3

Белок, вес, талия.
