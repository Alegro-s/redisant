package com.chairup.android.work

import android.content.Context
import androidx.core.app.NotificationManagerCompat
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.chairup.android.data.local.dao.WaistEntryDao
import com.chairup.android.data.preferences.UserPreferencesRepository
import com.chairup.android.notifications.NotificationChannels
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.flow.first
import java.time.LocalDate
import java.time.temporal.ChronoUnit

@HiltWorker
class WaistReminderWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val waistDao: WaistEntryDao,
    private val preferences: UserPreferencesRepository,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        if (preferences.dndEnabled.first() && isQuietHours()) return Result.success()
        val latest = waistDao.getLatest() ?: return notifyIfAllowed()
        val last = LocalDate.parse(latest.date)
        val days = ChronoUnit.DAYS.between(last, LocalDate.now())
        if (days >= 14) {
            if (preferences.tryConsumeDailyNudge()) {
                notifyAndSuccess()
            }
        }
        return Result.success()
    }

    private suspend fun notifyIfAllowed(): Result {
        if (!preferences.tryConsumeDailyNudge()) return Result.success()
        return notifyAndSuccess()
    }

    private fun notifyAndSuccess(): Result {
        NotificationChannels.ensure(applicationContext)
        val n = NotificationChannels.microNudge(
            applicationContext,
            "Замер талии",
            "Раз в 2 недели — обхват важнее весов.",
        )
        NotificationManagerCompat.from(applicationContext).notify(NOTIFY_ID, n.build())
        return Result.success()
    }

    private fun isQuietHours(): Boolean {
        val h = java.time.LocalTime.now().hour
        return h >= 22 || h < 8
    }

    companion object {
        const val WORK_NAME = "waist_reminder"
        private const val NOTIFY_ID = 2002
    }
}
