package com.chairup.android.data.repository

import com.chairup.android.data.local.dao.DailyAggregateDao
import com.chairup.android.data.local.dao.UserProfileDao
import com.chairup.android.data.local.dao.WeightEntryDao
import com.chairup.android.domain.WeightTrend
import com.chairup.android.domain.nutrition.ProteinPresets
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import javax.inject.Singleton

data class WeeklyReportUiState(
    val microTotal: Int = 0,
    val avgProteinRatio: Float = 0f,
    val avgScore: Float = 0f,
    val successfulDays: Int = 0,
    val weightTrendKg: Float = 0f,
    val summary: String = "Недельный отчёт появится после 2+ дней данных",
    val hasEnoughData: Boolean = false,
)

@Singleton
class CoachRepository @Inject constructor(
    private val dailyDao: DailyAggregateDao,
    private val weightDao: WeightEntryDao,
    private val profileDao: UserProfileDao,
) {
    private val dateFmt = DateTimeFormatter.ISO_LOCAL_DATE

    fun observeWeeklyReport(): Flow<WeeklyReportUiState> {
        val to = LocalDate.now()
        val from = to.minusDays(6)
        return combine(
            dailyDao.observeBetween(from.format(dateFmt), to.format(dateFmt)),
            weightDao.observeRecent(60),
            profileDao.observeProfile(),
        ) { rows, weights, profile ->
            if (rows.size < 2) return@combine WeeklyReportUiState()
            val micro = rows.sumOf { it.microDone }
            val proteinTarget = profile?.targetProteinG?.takeIf { it > 0f }
                ?: ProteinPresets.defaultTargetGrams(profile?.startWeightKg ?: 88f)
            val proteinRatios = rows.map { row ->
                if (row.proteinG > 0f && proteinTarget > 0f) {
                    (row.proteinG / proteinTarget).coerceIn(0f, 1f)
                } else 0f
            }
            val avgProtein = proteinRatios.average().toFloat()
            val avgScore = rows.map { it.dailyScore }.average().toFloat()
            val success = rows.count { it.dailyScore >= 70f }
            val trendPoints = WeightTrend.movingAverage7(weights)
            val first = trendPoints.firstOrNull()?.ma7 ?: trendPoints.firstOrNull()?.kg
            val last = trendPoints.lastOrNull()?.ma7 ?: trendPoints.lastOrNull()?.kg
            val trendKg = if (first != null && last != null) last - first else 0f
            val sign = if (trendKg <= 0f) "" else "+"
            WeeklyReportUiState(
                microTotal = micro,
                avgProteinRatio = avgProtein,
                avgScore = avgScore,
                successfulDays = success,
                weightTrendKg = trendKg,
                hasEnoughData = true,
                summary = "$sign${"%.1f".format(trendKg)} кг тренд · $micro микро · $success/7 дней 70+",
            )
        }
    }
}
