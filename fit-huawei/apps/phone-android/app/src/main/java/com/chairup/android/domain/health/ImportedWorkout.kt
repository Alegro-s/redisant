package com.chairup.android.domain.health

data class ImportedWorkout(
    val activityName: String,
    val durationSec: Int,
    val startTimeMillis: Long,
    val endTimeMillis: Long,
)
