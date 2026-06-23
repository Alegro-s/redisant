package com.chairup.android.data.repository

import com.chairup.android.data.local.dao.DailyAggregateDao
import com.chairup.android.data.local.dao.UserProfileDao
import com.chairup.android.data.local.dao.WaistEntryDao
import com.chairup.android.data.local.dao.WeightEntryDao
import com.chairup.android.data.local.entity.DailyAggregateEntity
import com.chairup.android.data.local.entity.UserProfileEntity
import com.chairup.android.data.local.entity.WaistEntryEntity
import com.chairup.android.data.local.entity.WeightEntryEntity
import com.chairup.android.domain.DailyScoreCalculator
import com.chairup.android.domain.WeightTrend
import com.chairup.android.domain.WeightPoint
import com.chairup.android.domain.nutrition.ProteinPreset
import com.chairup.android.domain.nutrition.ProteinPresets
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

data class NutritionUiState(
    val proteinG: Float = 0f,
    val proteinTargetG: Float = 158f,
    val proteinRatio: Float = 0f,
    val presets: List<ProteinPreset> = ProteinPresets.all,
    val weightPoints: List<WeightPoint> = emptyList(),
    val latestWeightKg: Float? = null,
    val startWeightKg: Float = 88f,
    val latestWaistCm: Float? = null,
    val daysSinceWaist: Long = 0,
    val waistDue: Boolean = false,
    val waveWeek: Int = 1,
    val calorieHint: String? = null,
)

@Singleton
class NutritionRepository @Inject constructor(
    private val dailyDao: DailyAggregateDao,
    private val profileDao: UserProfileDao,
    private val weightDao: WeightEntryDao,
    private val waistDao: WaistEntryDao,
    private val microRepository: MicroRepository,
) {
    private val dateFmt = DateTimeFormatter.ISO_LOCAL_DATE

    fun observeNutrition(installTs: Flow<Long>): Flow<NutritionUiState> {
        val today = LocalDate.now().format(dateFmt)
        return combine(
            dailyDao.observeByDate(today),
            profileDao.observeProfile(),
            weightDao.observeRecent(60),
            waistDao.observeLatest(),
            installTs,
        ) { daily, profile, weights, waist, install ->
            val p = profile ?: UserProfileEntity()
            val target = p.targetProteinG.takeIf { it > 0 }
                ?: ProteinPresets.defaultTargetGrams(p.startWeightKg)
            val protein = daily?.proteinG ?: 0f
            val points = WeightTrend.movingAverage7(weights)
            val latestW = weights.maxByOrNull { it.recordedAt }?.weightKg
            val waistDate = waist?.date?.let { LocalDate.parse(it) }
            val daysSince = waistDate?.let { ChronoUnit.DAYS.between(it, LocalDate.now()) } ?: 99
            val week = com.chairup.android.domain.WaveProgression.weekNumber(install)
            NutritionUiState(
                proteinG = protein,
                proteinTargetG = target,
                proteinRatio = if (target > 0) (protein / target).coerceIn(0f, 1f) else 0f,
                weightPoints = points.takeLast(30),
                latestWeightKg = latestW,
                startWeightKg = p.startWeightKg,
                latestWaistCm = waist?.waistCm,
                daysSinceWaist = daysSince,
                waistDue = daysSince >= 14,
                waveWeek = week,
                calorieHint = if (week >= 3) "Ориентир: −300 ккал/день (без подсчёта каждой крошки)" else null,
            )
        }
    }

    suspend fun addProtein(grams: Float) {
        val today = LocalDate.now().format(dateFmt)
        val row = dailyDao.getByDate(today) ?: DailyAggregateEntity(date = today)
        dailyDao.upsert(row.copy(proteinG = row.proteinG + grams, updatedAt = System.currentTimeMillis()))
        microRepository.refreshDailyAggregateForToday()
    }

    suspend fun copyProteinFromYesterday() {
        val today = LocalDate.now()
        val yesterday = today.minusDays(1).format(dateFmt)
        val yRow = dailyDao.getByDate(yesterday) ?: return
        val todayStr = today.format(dateFmt)
        val row = dailyDao.getByDate(todayStr) ?: DailyAggregateEntity(date = todayStr)
        dailyDao.upsert(row.copy(proteinG = yRow.proteinG, updatedAt = System.currentTimeMillis()))
        microRepository.refreshDailyAggregateForToday()
    }

    suspend fun setProteinTarget(grams: Float) {
        val profile = profileDao.observeProfile().first() ?: UserProfileEntity()
        profileDao.upsert(profile.copy(targetProteinG = grams.coerceIn(80f, 250f)))
        microRepository.refreshDailyAggregateForToday()
    }

    suspend fun logWeight(kg: Float) {
        require(kg in 40f..200f) { "Некорректный вес" }
        val today = LocalDate.now().format(dateFmt)
        weightDao.insert(
            WeightEntryEntity(
                id = UUID.randomUUID().toString(),
                date = today,
                weightKg = kg,
                recordedAt = System.currentTimeMillis(),
            ),
        )
        microRepository.refreshDailyAggregateForToday()
    }

    suspend fun logWaist(cm: Float) {
        require(cm in 50f..200f) { "Некорректный обхват" }
        val today = LocalDate.now().format(dateFmt)
        waistDao.insert(
            WaistEntryEntity(
                id = UUID.randomUUID().toString(),
                date = today,
                waistCm = cm,
                recordedAt = System.currentTimeMillis(),
            ),
        )
    }

    suspend fun weightTrendRatio(): Float {
        val profile = profileDao.observeProfile().first() ?: UserProfileEntity()
        val weights = weightDao.getAllAscending()
        return WeightTrend.trendRatio(weights, profile.startWeightKg)
    }
}
