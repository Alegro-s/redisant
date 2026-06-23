package com.chairup.android.domain.strength

object StrengthProgression {
    /** +1 повтор (или секунда для планки) за каждую неделю с установки. */
    fun targetReps(baseReps: Int, weekNumber: Int): Int =
        baseReps + (weekNumber - 1).coerceAtLeast(0)

    fun weeklySessionGoal(): Int = 2
}
