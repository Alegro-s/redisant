package com.chairup.android.data.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "chairup_prefs")

@Singleton
class UserPreferencesRepository @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val onboardingDone = booleanPreferencesKey("onboarding_done")
    private val chairMode = booleanPreferencesKey("chair_mode")
    private val installTs = longPreferencesKey("install_ts")
    private val dnd = booleanPreferencesKey("dnd_22_08")
    private val lastNudgeAt = longPreferencesKey("last_nudge_at")
    private val nudgeDay = longPreferencesKey("nudge_day_epoch")
    private val nudgeCount = longPreferencesKey("nudge_count")
    private val celebratedDay = longPreferencesKey("celebrated_day")
    private val stepBonusWeeks = longPreferencesKey("step_bonus_weeks")
    private val lastStepBonusWeek = longPreferencesKey("last_step_bonus_week")

    val onboardingComplete: Flow<Boolean> =
        context.dataStore.data.map { it[onboardingDone] == true }

    val chairModeEnabled: Flow<Boolean> =
        context.dataStore.data.map { it[chairMode] != false }

    val installTimestamp: Flow<Long> = context.dataStore.data.map { prefs ->
        prefs[installTs] ?: 0L
    }

    val dndEnabled: Flow<Boolean> = context.dataStore.data.map { it[dnd] == true }

    suspend fun ensureInstallTimestamp() {
        context.dataStore.edit { prefs ->
            if (prefs[installTs] == null || prefs[installTs] == 0L) {
                prefs[installTs] = System.currentTimeMillis()
            }
        }
    }

    suspend fun setOnboardingComplete() {
        context.dataStore.edit {
            it[onboardingDone] = true
            if (it[installTs] == null || it[installTs] == 0L) {
                it[installTs] = System.currentTimeMillis()
            }
        }
    }

    suspend fun setChairMode(enabled: Boolean) {
        context.dataStore.edit { it[chairMode] = enabled }
    }

    suspend fun setDnd(enabled: Boolean) {
        context.dataStore.edit { it[dnd] = enabled }
    }

    suspend fun markNudgeSent() {
        context.dataStore.edit { it[lastNudgeAt] = System.currentTimeMillis() }
    }

    suspend fun tryConsumeDailyNudge(limitPerDay: Int = 6): Boolean {
        val todayEpochDay = LocalDate.now().toEpochDay()
        var allowed = false
        context.dataStore.edit { prefs ->
            val day = prefs[nudgeDay] ?: -1L
            val count = if (day == todayEpochDay) (prefs[nudgeCount] ?: 0) else 0
            if (count < limitPerDay) {
                prefs[nudgeDay] = todayEpochDay
                prefs[nudgeCount] = count + 1
                prefs[lastNudgeAt] = System.currentTimeMillis()
                allowed = true
            }
        }
        return allowed
    }

    suspend fun getLastNudgeAt(): Long =
        context.dataStore.data.map { it[lastNudgeAt] ?: 0L }.first()

    val celebratedToday: Flow<Boolean> = context.dataStore.data.map { prefs ->
        prefs[celebratedDay] == LocalDate.now().toEpochDay()
    }

    suspend fun markCelebratedToday() {
        context.dataStore.edit { it[celebratedDay] = LocalDate.now().toEpochDay() }
    }

    val stepBonusWeeksCount: Flow<Int> = context.dataStore.data.map { prefs ->
        (prefs[stepBonusWeeks] ?: 0L).toInt()
    }

    suspend fun getNudgeCountToday(): Int {
        val todayEpochDay = LocalDate.now().toEpochDay()
        val prefs = context.dataStore.data.first()
        return if (prefs[nudgeDay] == todayEpochDay) (prefs[nudgeCount] ?: 0).toInt() else 0
    }

    /** +500 шагов за каждую успешную неделю (≥5 дней score 70+). */
    suspend fun refreshStepBonusWeeks(successfulDaysLast7: Int) {
        if (successfulDaysLast7 < 5) return
        val week = LocalDate.now().get(java.time.temporal.WeekFields.ISO.weekOfWeekBasedYear()).toLong()
        context.dataStore.edit { prefs ->
            val last = prefs[lastStepBonusWeek] ?: -1L
            if (last != week) {
                prefs[lastStepBonusWeek] = week
                prefs[stepBonusWeeks] = (prefs[stepBonusWeeks] ?: 0L) + 1L
            }
        }
    }
}
