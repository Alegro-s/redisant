package com.chairup.android.ui.navigation

object Routes {
    const val Onboarding = "onboarding"
    const val Today = "today"
    const val Body = "body"
    const val Strength = "strength"
    const val Health = "health"
    const val StrengthWorkout = "strength_workout/{templateId}"
    const val Settings = "settings"
    const val MicroTimer = "micro_timer/{slotIndex}"
    const val WeeklyReport = "weekly_report"
    const val Privacy = "privacy"

    fun microTimer(slotIndex: Int) = "micro_timer/$slotIndex"

    fun strengthWorkout(templateId: String) = "strength_workout/$templateId"
}
