package com.chairup.android.domain.strength

data class StrengthExercise(
    val id: String,
    val name: String,
    val baseReps: Int,
    val sets: Int = 3,
    val restSec: Int = 60,
    val hint: String = "",
)
