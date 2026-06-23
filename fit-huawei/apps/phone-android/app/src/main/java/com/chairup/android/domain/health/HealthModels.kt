package com.chairup.android.domain.health

data class DaySteps(
    val date: String,
    val steps: Int,
)

data class SleepSummary(
    val totalMinutes: Int,
    val date: String,
)

data class HealthMetrics(
    val todaySteps: Int,
    val stepsLast7Days: List<DaySteps>,
    val lastSleep: SleepSummary?,
    val restingHeartRate: Int?,
    val syncedAtMillis: Long,
    val source: HealthSource,
)

enum class HealthSource {
    HMS,
    CACHE,
}
