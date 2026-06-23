package com.chairup.android.data.repository

import com.chairup.android.data.local.dao.DailyAggregateDao
import com.chairup.android.data.local.dao.HealthDayDao
import com.chairup.android.data.local.entity.DailyAggregateEntity
import com.chairup.android.data.local.entity.HealthDayEntity
import com.chairup.android.domain.health.DaySteps
import com.chairup.android.domain.health.HealthMetrics
import com.chairup.android.domain.health.HealthSource
import com.chairup.android.domain.health.SleepSummary
import com.chairup.android.integration.health.HealthGateway
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import javax.inject.Singleton

data class MetricsUiState(
    val todaySteps: Int = 0,
    val stepsLast7Days: List<Pair<String, Int>> = emptyList(),
    val sleepMinutes: Int? = null,
    val sleepLabel: String = "—",
    val restingHr: Int? = null,
    val lastSyncedAt: Long? = null,
    val isSyncing: Boolean = false,
    val syncError: String? = null,
    val hmsConfigured: Boolean = false,
)

@Singleton
class HealthRepository @Inject constructor(
    private val gateway: HealthGateway,
    private val healthDayDao: HealthDayDao,
    private val dailyDao: DailyAggregateDao,
    private val microRepository: MicroRepository,
) {
    private val dateFmt = DateTimeFormatter.ISO_LOCAL_DATE

    fun observeMetrics(): Flow<MetricsUiState> {
        val today = LocalDate.now().format(dateFmt)
        return combine(
            healthDayDao.observeAll(),
            dailyDao.observeByDate(today),
        ) { days, todayRow ->
            val sorted = days.sortedBy { it.date }
            val todaySteps = sorted.lastOrNull { it.date == today }?.steps
                ?: todayRow?.stepsFromHms
                ?: todayRow?.steps
                ?: 0
            val sleep = todayRow?.sleepMinutes ?: sorted.lastOrNull()?.sleepMinutes
            MetricsUiState(
                todaySteps = todaySteps,
                stepsLast7Days = sorted.takeLast(7).map { it.date to it.steps },
                sleepMinutes = sleep,
                sleepLabel = sleep?.let { formatSleep(it) } ?: "—",
                restingHr = todayRow?.restingHr ?: sorted.lastOrNull()?.restingHr,
                lastSyncedAt = sorted.maxOfOrNull { it.syncedAt },
                hmsConfigured = gateway.isHmsConfigured,
            )
        }
    }

    suspend fun syncFromHealth(): Result<HealthMetrics> {
        val remote = gateway.readMetrics()
        if (remote.isSuccess) {
            persist(remote.getOrThrow())
            microRepository.refreshDailyAggregateForToday()
            return remote
        }
        val cached = loadFromCache()
        return if (cached.isSuccess) cached else remote
    }

    private suspend fun loadFromCache(): Result<HealthMetrics> {
        val all = healthDayDao.getAll()
        if (all.isEmpty()) {
            return Result.failure(IllegalStateException("Нет кэша. Подключите HUAWEI Health."))
        }
        val today = LocalDate.now().format(dateFmt)
        val todayRow = healthDayDao.getByDate(today)
        val sleepMin = todayRow?.sleepMinutes
        return Result.success(
            HealthMetrics(
                todaySteps = todayRow?.steps ?: all.maxByOrNull { it.date }?.steps ?: 0,
                stepsLast7Days = all.sortedBy { it.date }.map { DaySteps(it.date, it.steps) },
                lastSleep = sleepMin?.let { SleepSummary(it, todayRow?.date ?: today) },
                restingHeartRate = todayRow?.restingHr,
                syncedAtMillis = healthDayDao.lastSyncedAt() ?: 0L,
                source = HealthSource.CACHE,
            ),
        )
    }

    private suspend fun persist(metrics: HealthMetrics) {
        val now = metrics.syncedAtMillis
        val today = LocalDate.now().format(dateFmt)
        val rows = metrics.stepsLast7Days.map { day ->
            HealthDayEntity(
                date = day.date,
                steps = day.steps,
                sleepMinutes = if (day.date == metrics.lastSleep?.date) metrics.lastSleep.totalMinutes else null,
                restingHr = if (day.date == today) metrics.restingHeartRate else null,
                syncedAt = now,
            )
        }
        healthDayDao.upsertAll(rows)
        val existing = dailyDao.getByDate(today)
        dailyDao.upsert(
            (existing ?: DailyAggregateEntity(date = today)).copy(
                steps = metrics.todaySteps,
                stepsFromHms = metrics.todaySteps,
                sleepMinutes = metrics.lastSleep?.totalMinutes,
                restingHr = metrics.restingHeartRate,
                updatedAt = now,
            ),
        )
    }

    private fun formatSleep(minutes: Int): String {
        val h = minutes / 60
        val m = minutes % 60
        return "${h}ч ${m}м"
    }
}
