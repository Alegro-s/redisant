package com.chairup.android.work

import android.content.Context
import androidx.core.app.NotificationManagerCompat
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.chairup.android.data.preferences.UserPreferencesRepository
import com.chairup.android.data.repository.MicroRepository
import com.chairup.android.domain.micro.MicroSlotPlanner
import com.chairup.android.notifications.NotificationChannels
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.flow.first
import java.time.LocalTime

@HiltWorker
class ChairNudgeWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val preferences: UserPreferencesRepository,
    private val microRepository: MicroRepository,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        NotificationChannels.ensure(applicationContext)
        val chairMode = preferences.chairModeEnabled.first()
        if (!chairMode) return Result.success()

        if (preferences.dndEnabled.first() && isQuietHours()) {
            return Result.success()
        }

        val lastNudge = preferences.getLastNudgeAt()
        val cooldownMs = 45 * 60 * 1000L
        if (System.currentTimeMillis() - lastNudge < cooldownMs) {
            return Result.success()
        }

        val micro = microRepository.observeMicroState().first()
        if (micro.microDone >= micro.microTarget) return Result.success()

        val next = micro.nextSlot ?: return Result.success()
        val minutes = MicroSlotPlanner.minutesUntil(next)
        if (minutes > 10) return Result.success()

        val notification = NotificationChannels.microNudge(
            applicationContext,
            "2 минуты — встань",
            "Слот ${next.label}. Это уже победа.",
        )
        if (!preferences.tryConsumeDailyNudge()) return Result.success()
        NotificationManagerCompat.from(applicationContext)
            .notify(NOTIFICATION_ID, notification.build())
        return Result.success()
    }

    private fun isQuietHours(): Boolean {
        val now = LocalTime.now()
        return now.hour >= 22 || now.hour < 8
    }

    companion object {
        const val WORK_NAME = "chair_nudge"
        private const val NOTIFICATION_ID = 2001
    }
}
