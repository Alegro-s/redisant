package com.chairup.android.data.repository

import com.chairup.android.data.local.dao.DailyAggregateDao
import com.chairup.android.data.local.dao.HealthDayDao
import com.chairup.android.data.local.dao.MicroSessionDao
import com.chairup.android.data.local.dao.UserProfileDao
import com.chairup.android.data.local.entity.DailyAggregateEntity
import com.chairup.android.data.local.entity.MicroSessionEntity
import com.chairup.android.data.preferences.UserPreferencesRepository
import com.chairup.android.domain.DailyScoreCalculator
import com.chairup.android.domain.WeightTrend
import com.chairup.android.domain.WaveProgression
import com.chairup.android.domain.nutrition.ProteinPresets
import com.chairup.android.domain.micro.MicroSlot
import com.chairup.android.domain.micro.MicroSlotPlanner
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flatMapLatest
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

data class MicroUiState(
    val microDone: Int = 0,
    val microTarget: Int = 4,
    val chairMode: Boolean = true,
    val completedSlotIndices: Set<Int> = emptySet(),
    val slots: List<MicroSlot> = emptyList(),
    val nextSlot: MicroSlot? = null,
    val nextSlotInMin: Int = 0,
    val waveWeek: Int = 1,
    val stepGoal: Int = 4000,
)

@Singleton
class MicroRepository @Inject constructor(
    private val microDao: MicroSessionDao,
    private val dailyDao: DailyAggregateDao,
    private val profileDao: UserProfileDao,
    private val healthDayDao: HealthDayDao,
    private val weightDao: com.chairup.android.data.local.dao.WeightEntryDao,
    private val preferences: UserPreferencesRepository,
) {
    private val dateFmt = DateTimeFormatter.ISO_LOCAL_DATE

    fun observeMicroState(): Flow<MicroUiState> {
        val today = LocalDate.now().format(dateFmt)
        return preferences.stepBonusWeeksCount.flatMapLatest { bonusWeeks ->
            combine(
                microDao.observeByDate(today),
                preferences.chairModeEnabled,
                preferences.installTimestamp,
                profileDao.observeProfile(),
            ) { sessions, chairMode, installTs, profile ->
                val week = WaveProgression.weekNumber(installTs)
                val target = WaveProgression.microTargetForWeek(week)
                val slots = MicroSlotPlanner.slotsForToday(target)
                val done = sessions.map { it.slotIndex }.toSet()
                val next = MicroSlotPlanner.nextSlot(slots, done)
                val baseline = profile?.baselineSteps?.takeIf { it > 0 } ?: 4000
                val adaptiveBonus = bonusWeeks * 500
                val stepGoal = baseline + WaveProgression.stepBonusForWeek(week) + adaptiveBonus
                MicroUiState(
                    microDone = sessions.size,
                    microTarget = target,
                    chairMode = chairMode,
                    completedSlotIndices = done,
                    slots = slots,
                    nextSlot = next,
                    nextSlotInMin = next?.let { MicroSlotPlanner.minutesUntil(it) } ?: 0,
                    waveWeek = week,
                    stepGoal = stepGoal,
                )
            }
        }
    }

    private suspend fun computeBaseline(): Int {
        val days = healthDayDao.getAll().takeLast(7)
        if (days.isEmpty()) return 4000
        return (days.map { it.steps }.average()).toInt().coerceAtLeast(2000)
    }

    suspend fun ensureInitialized() {
        preferences.ensureInstallTimestamp()
        refreshDailyAggregateForToday()
    }

    suspend fun setChairMode(enabled: Boolean) {
        preferences.setChairMode(enabled)
    }

    suspend fun completeMicroSession(
        slotIndex: Int,
        durationSec: Int,
        source: String = "phone",
    ): Result<Unit> = runCatching {
        val today = LocalDate.now().format(dateFmt)
        val installTs = preferences.installTimestamp.first()
        val target = WaveProgression.microTargetForWeek(WaveProgression.weekNumber(installTs))
        require(slotIndex in 0 until target) { "Неверный слот" }
        require(durationSec >= 60) { "Минимум 60 секунд" }

        microDao.insert(
            MicroSessionEntity(
                id = UUID.randomUUID().toString(),
                date = today,
                slotIndex = slotIndex,
                durationSec = durationSec,
                completedAt = System.currentTimeMillis(),
                source = source,
            ),
        )
        refreshDailyAggregate(today)
    }

    suspend fun completeNextAvailableSlot(durationSec: Int = 120, source: String = "phone"): Result<Int> {
        val state = observeMicroState().first()
        val nextIndex = state.nextSlot?.index
            ?: state.slots.firstOrNull { it.index !in state.completedSlotIndices }?.index
            ?: return Result.failure(IllegalStateException("Все слоты на сегодня выполнены"))
        return completeMicroSession(nextIndex, durationSec, source).map { nextIndex }
    }

    private suspend fun refreshDailyAggregate(date: String) {
        val count = microDao.countByDate(date)
        val installTs = preferences.installTimestamp.first()
        val week = WaveProgression.weekNumber(installTs)
        val target = WaveProgression.microTargetForWeek(week)
        val profile = profileDao.observeProfile().first()
        val baseline = profile?.baselineSteps?.takeIf { it > 0 } ?: computeBaseline()
        val adaptiveBonus = preferences.stepBonusWeeksCount.first() * 500
        val stepGoal = baseline + WaveProgression.stepBonusForWeek(week) + adaptiveBonus
        val todayHealth = healthDayDao.getByDate(date)
        val existing = dailyDao.getByDate(date) ?: DailyAggregateEntity(date = date)
        val steps = todayHealth?.steps ?: existing.stepsFromHms.takeIf { it > 0 } ?: existing.steps
        val proteinTarget = profile?.targetProteinG?.takeIf { it > 0 }
            ?: ProteinPresets.defaultTargetGrams(profile?.startWeightKg ?: 88f)
        val weights = weightDao.getAllAscending()
        val trend = WeightTrend.trendRatio(weights, profile?.startWeightKg ?: 88f)
        val row = existing.copy(
            microDone = count,
            microTarget = target,
            steps = steps,
            stepsFromHms = todayHealth?.steps ?: existing.stepsFromHms,
        )
        dailyDao.upsert(
            row.copy(
                dailyScore = DailyScoreCalculator.calculate(
                    row,
                    stepGoal,
                    proteinTarget,
                    trend,
                    strengthDone = row.strengthDone,
                ),
                updatedAt = System.currentTimeMillis(),
            ),
        )
        val successful = dailyDao.countSuccessfulDays(
            fromDate = LocalDate.now().minusDays(7).format(dateFmt),
            toDate = LocalDate.now().minusDays(1).format(dateFmt),
            minScore = 70f,
        )
        preferences.refreshStepBonusWeeks(successful)
    }

    suspend fun refreshDailyAggregateForToday() {
        refreshDailyAggregate(LocalDate.now().format(dateFmt))
    }
}
