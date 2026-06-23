package com.chairup.android

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.chairup.android.notifications.NotificationChannels
import com.chairup.android.integration.wear.WearSyncManager
import com.chairup.android.work.ChairNudgeWorker
import com.chairup.android.work.CoachRulesWorker
import com.chairup.android.work.WaistReminderWorker
import java.util.concurrent.TimeUnit
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class ChairUpApplication : Application(), androidx.work.Configuration.Provider {

    @Inject lateinit var workerFactory: HiltWorkerFactory
    @Inject lateinit var wearSyncManager: WearSyncManager

    override fun onCreate() {
        super.onCreate()
        NotificationChannels.ensure(this)
        wearSyncManager.start()
        scheduleNudgeWork()
        scheduleWaistReminder()
        scheduleCoachRules()
    }

    private fun scheduleNudgeWork() {
        val request = PeriodicWorkRequestBuilder<ChairNudgeWorker>(15, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            ChairNudgeWorker.WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    private fun scheduleWaistReminder() {
        val request = PeriodicWorkRequestBuilder<WaistReminderWorker>(1, TimeUnit.DAYS)
            .build()
        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            WaistReminderWorker.WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    private fun scheduleCoachRules() {
        val request = PeriodicWorkRequestBuilder<CoachRulesWorker>(1, TimeUnit.HOURS)
            .build()
        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            CoachRulesWorker.WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    override val workManagerConfiguration: androidx.work.Configuration
        get() = androidx.work.Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()
}
