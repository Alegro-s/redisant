package com.chairup.android.work

import android.content.Context
import androidx.core.app.NotificationManagerCompat
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.chairup.android.data.preferences.UserPreferencesRepository
import com.chairup.android.data.repository.MicroRepository
import com.chairup.android.data.repository.TodayRepository
import com.chairup.android.domain.coach.CoachContext
import com.chairup.android.domain.coach.CoachEngine
import com.chairup.android.integration.health.HealthGateway
import com.chairup.android.notifications.NotificationChannels
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.flow.first
import java.time.LocalTime
import java.util.concurrent.TimeUnit

@HiltWorker
class CoachRulesWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val preferences: UserPreferencesRepository,
    private val microRepository: MicroRepository,
    private val todayRepository: TodayRepository,
    private val coachEngine: CoachEngine,
    private val healthGateway: HealthGateway,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        NotificationChannels.ensure(applicationContext)
        val dnd = preferences.dndEnabled.first()
        if (dnd && isQuietHours()) return Result.success()

        val micro = microRepository.observeMicroState().first()
        val today = todayRepository.observeToday().first()
        val steps45 = healthGateway.readStepsSince(
            System.currentTimeMillis() - TimeUnit.MINUTES.toMillis(45),
        ).getOrDefault(0)
        val proteinRatio = if (today.proteinTargetG > 0f) today.proteinG / today.proteinTargetG else 0f
        val celebrated = preferences.celebratedToday.first()

        val ctx = CoachContext(
            chairMode = micro.chairMode,
            microDone = micro.microDone,
            microTarget = micro.microTarget,
            stepsLast45Min = steps45,
            proteinRatio = proteinRatio,
            dnd = dnd && isQuietHours(),
            celebratedToday = celebrated,
        )

        for (action in coachEngine.evaluate(ctx)) {
            when (action.action) {
                "in_app" -> {
                    if (action.ruleId == "celebrate_micro_complete" && !celebrated) {
                        preferences.markCelebratedToday()
                        if (preferences.tryConsumeDailyNudge()) {
                            notify(2103, action.title, action.message)
                        }
                    }
                }
                "notify" -> {
                    if (preferences.tryConsumeDailyNudge()) {
                        notify(
                            action.ruleId.hashCode() and 0xFFFF,
                            action.title,
                            action.message,
                        )
                    }
                }
            }
        }
        return Result.success()
    }

    private fun notify(id: Int, title: String, body: String) {
        NotificationManagerCompat.from(applicationContext).notify(
            id,
            NotificationChannels.microNudge(applicationContext, title, body).build(),
        )
    }

    private fun isQuietHours(): Boolean {
        val now = LocalTime.now()
        return now.hour >= 22 || now.hour < 8
    }

    companion object {
        const val WORK_NAME = "coach_rules"
    }
}
