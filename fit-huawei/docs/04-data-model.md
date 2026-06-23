# Модель данных

## ER (локальная БД телефона)

```mermaid
erDiagram
  USER_PROFILE ||--o{ DAILY_AGGREGATE : has
  USER_PROFILE ||--o{ WEIGHT_ENTRY : logs
  USER_PROFILE ||--o{ WAIST_ENTRY : logs
  DAILY_AGGREGATE ||--o{ MICRO_SESSION : contains
  DAILY_AGGREGATE ||--o{ PROTEIN_ENTRY : contains
  DAILY_AGGREGATE ||--o{ STRENGTH_WORKOUT : optional
  STRENGTH_WORKOUT ||--|{ STRENGTH_SET : has
  USER_PROFILE ||--o{ COACH_STATE : has

  USER_PROFILE {
    string id PK
    float start_weight_kg
    float target_protein_g
    int baseline_steps
    int current_wave
    bool chair_mode_default
    string annoyance_level
  }

  DAILY_AGGREGATE {
    string date PK
    int steps
    int steps_from_hms
    int micro_done
    int micro_target
    float protein_g
    float daily_score
    bool strength_done
    int sleep_minutes
    int resting_hr
  }

  MICRO_SESSION {
    string id PK
    string date FK
    int slot_index
    int duration_sec
    int hr_avg
    string source
    long completed_at
  }

  PROTEIN_ENTRY {
    string id PK
    string date FK
    float grams
    string preset_id
    long at
  }

  STRENGTH_WORKOUT {
    string id PK
    string date FK
    string template_id
    int duration_sec
  }

  STRENGTH_SET {
    string id PK
    string workout_id FK
    string exercise_id
    int reps
    float weight_kg
  }
```

## Domain events (внутренний bus)

| Event | Payload | Подписчики |
|-------|---------|------------|
| `HmsStepsUpdated` | `date, count, syncedAt` | RecalcScore, Widget |
| `MicroSessionCompleted` | `slotId, durationSec, source` | RecalcScore, WearSync |
| `ProteinLogged` | `grams, presetId?` | RecalcScore |
| `StrengthCompleted` | `templateId, sets[]` | RecalcScore |
| `WeightLogged` | `kg, at` | Trends, Coach |
| `ChairModeChanged` | `enabled` | Scheduler |
| `WaveAdvanced` | `waveNumber, params` | UI badge |

## HMS mapping

| ChairUp entity | HMS read | HMS write |
|----------------|----------|-----------|
| `DAILY_AGGREGATE.steps` | `DT_CONTINUOUS_STEPS_DELTA` | — |
| `DAILY_AGGREGATE.sleep_minutes` | `DT_CONTINUOUS_SLEEP` | — |
| `DAILY_AGGREGATE.resting_hr` | min HR sample 04–06 | — |
| `MICRO_SESSION` | — | опц. custom activity W4+ |
| `STRENGTH_WORKOUT` | `DT_CONTINUOUS_WORKOUT` import | — |

## Wear messages (v1)

См. `shared/contracts/wear-messages.schema.json`.

Типы:

- `STATE_PUSH` phone → watch  
- `MICRO_DONE` watch → phone  
- `START_MICRO` phone → watch  
- `STRENGTH_TICK` watch → phone (подход готов)  

## User goals (стартовые константы)

```kotlin
data class UserGoals(
  val microSlotsPerDay: Int = 8,
  val proteinGramsPerDay: Float,  // weight * 1.8f
  val strengthSessionsPerWeek: Int = 2,
  val weightTrendTargetKgPerWeek: Float = -0.4f,
  val waistRemindEveryDays: Int = 14,
)
```

При `current_wave` из профиля — `GoalRepository` подставляет ослабленные/усиленные значения.

## Room (фрагмент)

```kotlin
@Entity(tableName = "daily_aggregate")
data class DailyAggregateEntity(
  @PrimaryKey val date: String, // yyyy-MM-dd
  val steps: Int,
  val stepsFromHms: Int,
  val microDone: Int,
  val microTarget: Int,
  val proteinG: Float,
  val dailyScore: Float,
  val strengthDone: Boolean,
  val sleepMinutes: Int?,
  val restingHr: Int?,
  val updatedAt: Long,
)
```

Индексы: `date` PK, `micro_session(date, slot_index)` unique.

## Watch local store (HarmonyOS)

Минимум — **Preferences** + очередь исходящих:

```typescript
interface PendingOutbox {
  messages: WearMessage[];
}
```

Не хранить историю недель на часах — только `todayMicroDone: number[]`, `lastScore: number`.
