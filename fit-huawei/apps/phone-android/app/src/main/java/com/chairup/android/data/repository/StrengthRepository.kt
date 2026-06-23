package com.chairup.android.data.repository

import com.chairup.android.data.local.dao.DailyAggregateDao
import com.chairup.android.data.local.dao.StrengthWorkoutDao
import com.chairup.android.data.local.entity.DailyAggregateEntity
import com.chairup.android.data.local.entity.StrengthWorkoutEntity
import com.chairup.android.data.preferences.UserPreferencesRepository
import com.chairup.android.domain.WaveProgression
import com.chairup.android.domain.strength.StrengthExercise
import com.chairup.android.domain.strength.StrengthProgression
import com.chairup.android.domain.strength.StrengthTemplate
import com.chairup.android.domain.strength.StrengthTemplateId
import com.chairup.android.domain.strength.StrengthTemplates
import com.chairup.android.integration.health.HealthGateway
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import java.time.ZoneId
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.TemporalAdjusters
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

data class StrengthTemplateCard(
    val template: StrengthTemplate,
    val targetRepsByExercise: Map<String, Int>,
)

data class StrengthUiState(
    val weekNumber: Int = 1,
    val sessionsThisWeek: Int = 0,
    val weeklyGoal: Int = StrengthProgression.weeklySessionGoal(),
    val todayDone: Boolean = false,
    val lastWorkoutLabel: String? = null,
    val templates: List<StrengthTemplateCard> = emptyList(),
    val streakOk: Boolean = false,
)

@Singleton
class StrengthRepository @Inject constructor(
    private val workoutDao: StrengthWorkoutDao,
    private val dailyDao: DailyAggregateDao,
    private val microRepository: MicroRepository,
    private val preferences: UserPreferencesRepository,
    private val healthGateway: HealthGateway,
) {
    private val dateFmt = DateTimeFormatter.ISO_LOCAL_DATE

    fun observeStrength(): Flow<StrengthUiState> {
        val weekStart = currentWeekStart().format(dateFmt)
        return combine(
            workoutDao.observeSince(weekStart),
            preferences.installTimestamp,
        ) { workouts, installTs ->
            val week = WaveProgression.weekNumber(installTs)
            val cards = StrengthTemplates.all().map { template ->
                StrengthTemplateCard(
                    template = template,
                    targetRepsByExercise = template.exercises.associate { ex ->
                        ex.id to StrengthProgression.targetReps(ex.baseReps, week)
                    },
                )
            }
            val today = LocalDate.now().format(dateFmt)
            val todayDone = workouts.any { it.date == today }
            val last = workouts.maxByOrNull { it.completedAt }
            StrengthUiState(
                weekNumber = week,
                sessionsThisWeek = workouts.size,
                todayDone = todayDone,
                lastWorkoutLabel = last?.let { formatLast(it) },
                templates = cards,
                streakOk = workouts.size >= StrengthProgression.weeklySessionGoal(),
            )
        }
    }

    suspend fun completeWorkout(
        templateId: StrengthTemplateId,
        durationSec: Int,
        fromHealthImport: Boolean = false,
    ): Result<Unit> = runCatching {
        require(durationSec >= 60) { "Минимум 1 минута" }
        val today = LocalDate.now().format(dateFmt)
        val now = System.currentTimeMillis()
        workoutDao.insert(
            StrengthWorkoutEntity(
                id = UUID.randomUUID().toString(),
                date = today,
                templateId = templateId.key,
                durationSec = durationSec,
                completedAt = now,
                fromHealthImport = fromHealthImport,
            ),
        )
        val row = dailyDao.getByDate(today) ?: DailyAggregateEntity(date = today)
        dailyDao.upsert(row.copy(strengthDone = true, updatedAt = now))
        microRepository.refreshDailyAggregateForToday()
    }

    /** Импорт силовой из HUAWEI Health (DT_CONTINUOUS_WORKOUT). */
    suspend fun tryImportFromHealth(): Boolean {
        val today = LocalDate.now().format(dateFmt)
        if (workoutDao.latestOnDate(today) != null) return false
        val startOfDay = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val workouts = healthGateway.readRecentWorkouts(startOfDay).getOrNull().orEmpty()
        val candidate = workouts.firstOrNull { isStrengthWorkout(it.activityName) } ?: return false
        val templateId = mapTemplate(candidate.activityName)
        completeWorkout(templateId, candidate.durationSec, fromHealthImport = true).getOrThrow()
        return true
    }

    private fun isStrengthWorkout(name: String): Boolean {
        val n = name.lowercase()
        return n.contains("strength") || n.contains("workout") || n.contains("силов") ||
            n.contains("training") || n.contains("fitness")
    }

    private fun mapTemplate(name: String): StrengthTemplateId {
        val n = name.lowercase()
        return if (n.contains("b") || n.hashCode() % 2 == 0) StrengthTemplateId.B else StrengthTemplateId.A
    }

    fun exerciseTargets(template: StrengthTemplate, week: Int): List<StrengthExerciseUi> =
        template.exercises.map { ex ->
            StrengthExerciseUi(
                exercise = ex,
                targetReps = StrengthProgression.targetReps(ex.baseReps, week),
                sets = ex.sets,
            )
        }

    private fun formatLast(entity: StrengthWorkoutEntity): String {
        val name = StrengthTemplateId.fromKey(entity.templateId)?.let { StrengthTemplates.byId(it).title }
            ?: entity.templateId
        return "$name · ${entity.date}"
    }

    private fun currentWeekStart(): LocalDate =
        LocalDate.now().with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
}

data class StrengthExerciseUi(
    val exercise: StrengthExercise,
    val targetReps: Int,
    val sets: Int,
)
