package com.chairup.android.integration.health

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import com.chairup.android.BuildConfig
import com.chairup.android.domain.health.DaySteps
import com.chairup.android.domain.health.HealthMetrics
import com.chairup.android.domain.health.HealthSource
import com.chairup.android.domain.health.ImportedWorkout
import com.chairup.android.domain.health.SleepSummary
import com.huawei.hms.hihealth.HuaweiHiHealth
import com.huawei.hms.hihealth.SettingController
import com.huawei.hms.hihealth.data.DataType
import com.huawei.hms.hihealth.data.Field
import com.huawei.hms.hihealth.data.Scopes
import com.huawei.hms.hihealth.options.ActivityRecordReadOptions
import com.huawei.hms.hihealth.options.ReadOptions
import com.huawei.hms.support.hwid.HuaweiIdAuthManager
import com.huawei.hms.support.hwid.result.AuthHuaweiId
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DefaultHealthGateway @Inject constructor(
    @ApplicationContext private val context: Context,
) : HealthGateway {

    private val dateFmt = DateTimeFormatter.ISO_LOCAL_DATE
    private val zone = ZoneId.systemDefault()

    override val isHmsConfigured: Boolean = BuildConfig.HMS_ENABLED

    override suspend fun getAuthState(): HealthAuthState = withContext(Dispatchers.IO) {
        if (!isHmsConfigured) return@withContext HealthAuthState.NotConfigured
        runCatching {
            if (resolveAuthAccount() != null) {
                HealthAuthState.Authorized()
            } else {
                HealthAuthState.NotAuthorized
            }
        }.getOrElse { HealthAuthState.Error(it.message ?: "HMS error") }
    }

    override fun createAuthorizeIntent(): Intent? {
        if (!isHmsConfigured) {
            return context.packageManager.getLaunchIntentForPackage(HUAWEI_HEALTH_PKG)
                ?: Intent(Intent.ACTION_VIEW, Uri.parse(HUAWEI_HEALTH_WEB))
        }
        val activity = context.findActivity() ?: return null
        return try {
            settingController(activity).requestAuthorizationIntent(
                arrayOf(
                    Scopes.HEALTHKIT_STEP_READ,
                    Scopes.HEALTHKIT_SLEEP_READ,
                    Scopes.HEALTHKIT_HEARTRATE_READ,
                    Scopes.HEALTHKIT_ACTIVITY_READ,
                ),
                true,
            )
        } catch (_: Exception) {
            context.packageManager.getLaunchIntentForPackage(HUAWEI_HEALTH_PKG)
        }
    }

    override suspend fun readMetrics(): Result<HealthMetrics> = withContext(Dispatchers.IO) {
        if (!isHmsConfigured) {
            return@withContext Result.failure(IllegalStateException("Нет agconnect-services.json"))
        }
        val auth = resolveAuthAccount()
            ?: return@withContext Result.failure(IllegalStateException("Нужна авторизация HUAWEI Health"))

        runCatching {
            val dataController = HuaweiHiHealth.getDataController(context, auth)
            val today = LocalDate.now(zone)
            val days = (6 downTo 0).map { today.minusDays(it.toLong()) }
            val stepsByDay = days.associateWith { date -> readStepsForDay(dataController, date) }
            val todaySteps = stepsByDay[today] ?: 0
            val sleep = readLastSleep(dataController, today)
            val hr = readRestingHeartRate(dataController, today)

            HealthMetrics(
                todaySteps = todaySteps,
                stepsLast7Days = stepsByDay.map { (d, s) -> DaySteps(d.format(dateFmt), s) },
                lastSleep = sleep,
                restingHeartRate = hr,
                syncedAtMillis = System.currentTimeMillis(),
                source = HealthSource.HMS,
            )
        }
    }

    override suspend fun readRecentWorkouts(sinceMillis: Long): Result<List<ImportedWorkout>> =
        withContext(Dispatchers.IO) {
            if (!isHmsConfigured) {
                return@withContext Result.failure(IllegalStateException("Нет agconnect-services.json"))
            }
            val auth = resolveAuthAccount()
                ?: return@withContext Result.failure(IllegalStateException("Нужна авторизация HUAWEI Health"))
            runCatching {
                val end = System.currentTimeMillis()
                val activityController = HuaweiHiHealth.getActivityRecordsController(context, auth)
                val readOptions = ActivityRecordReadOptions.Builder()
                    .readActivityRecordsFromAllApps()
                    .setTimeInterval(sinceMillis, end, TimeUnit.MILLISECONDS)
                    .build()
                val reply = activityController.getActivityRecord(readOptions).awaitHuawei()
                reply.activityRecords.mapNotNull { record ->
                    val start = record.getStartTime(TimeUnit.MILLISECONDS)
                    val endT = record.getEndTime(TimeUnit.MILLISECONDS)
                    val durationSec = ((endT - start) / 1000L).toInt().coerceAtLeast(0)
                    if (durationSec < 600) return@mapNotNull null
                    ImportedWorkout(
                        activityName = "strength-workout",
                        durationSec = durationSec,
                        startTimeMillis = start,
                        endTimeMillis = endT,
                    )
                }.sortedByDescending { it.startTimeMillis }
            }
        }

    override suspend fun readStepsSince(sinceMillis: Long): Result<Int> = withContext(Dispatchers.IO) {
        if (!isHmsConfigured) return@withContext Result.success(0)
        val auth = resolveAuthAccount() ?: return@withContext Result.success(0)
        runCatching {
            val dataController = HuaweiHiHealth.getDataController(context, auth)
            val end = System.currentTimeMillis()
            val readOptions = ReadOptions.Builder()
                .read(DataType.DT_CONTINUOUS_STEPS_DELTA)
                .setTimeRange(sinceMillis, end, TimeUnit.MILLISECONDS)
                .build()
            val reply = dataController.read(readOptions).awaitHuawei()
            var total = 0
            for (set in reply.sampleSets) {
                for (sample in set.samplePoints) {
                    val field = sample.getFieldValue(Field.FIELD_STEPS)
                    if (field is Number) total += field.toInt()
                }
            }
            total
        }
    }

    private fun resolveAuthAccount(): AuthHuaweiId? {
        return try {
            HuaweiIdAuthManager.getAuthResult()
        } catch (_: Exception) {
            null
        }
    }

    private fun settingController(activity: Activity): SettingController =
        HuaweiHiHealth.getSettingController(activity)

    private suspend fun readStepsForDay(
        dataController: com.huawei.hms.hihealth.DataController,
        date: LocalDate,
    ): Int {
        val start = date.atStartOfDay(zone).toInstant().toEpochMilli()
        val end = date.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli() - 1
        val readOptions = ReadOptions.Builder()
            .read(DataType.DT_CONTINUOUS_STEPS_DELTA)
            .setTimeRange(start, end, TimeUnit.MILLISECONDS)
            .build()
        val reply = dataController.read(readOptions).awaitHuawei()
        var total = 0
        for (set in reply.sampleSets) {
            for (sample in set.samplePoints) {
                val field = sample.getFieldValue(Field.FIELD_STEPS)
                if (field is Number) total += field.toInt()
            }
        }
        return total
    }

    private suspend fun readLastSleep(
        dataController: com.huawei.hms.hihealth.DataController,
        today: LocalDate,
    ): SleepSummary? {
        val start = today.minusDays(1).atStartOfDay(zone).toInstant().toEpochMilli()
        val end = today.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli()
        val readOptions = ReadOptions.Builder()
            .read(DataType.DT_CONTINUOUS_SLEEP)
            .setTimeRange(start, end, TimeUnit.MILLISECONDS)
            .build()
        val reply = dataController.read(readOptions).awaitHuawei()
        var minutes = 0
        for (set in reply.sampleSets) {
            for (sample in set.samplePoints) {
                val startT = sample.getStartTime(TimeUnit.MILLISECONDS)
                val endT = sample.getEndTime(TimeUnit.MILLISECONDS)
                minutes += ((endT - startT) / 60_000L).toInt().coerceAtLeast(0)
            }
        }
        if (minutes <= 0) return null
        return SleepSummary(totalMinutes = minutes, date = today.minusDays(1).format(dateFmt))
    }

    private suspend fun readRestingHeartRate(
        dataController: com.huawei.hms.hihealth.DataController,
        today: LocalDate,
    ): Int? {
        val start = today.atStartOfDay(zone).toInstant().toEpochMilli()
        val end = System.currentTimeMillis()
        val readOptions = ReadOptions.Builder()
            .read(DataType.DT_INSTANTANEOUS_HEART_RATE)
            .setTimeRange(start, end, TimeUnit.MILLISECONDS)
            .build()
        val reply = dataController.read(readOptions).awaitHuawei()
        var minHr: Int? = null
        for (set in reply.sampleSets) {
            for (sample in set.samplePoints) {
                val bpm = sample.getFieldValue(Field.FIELD_BPM)
                if (bpm is Number) {
                    val v = bpm.toInt()
                    if (v in 40..120 && (minHr == null || v < minHr!!)) minHr = v
                }
            }
        }
        return minHr
    }

    companion object {
        const val AUTH_REQUEST_CODE = 1001
        private const val HUAWEI_HEALTH_PKG = "com.huawei.health"
        private const val HUAWEI_HEALTH_WEB = "https://consumer.huawei.com/en/mobileservices/health/"
    }
}

private fun Context.findActivity(): Activity? {
    var ctx: Context? = this
    while (ctx is android.content.ContextWrapper) {
        if (ctx is Activity) return ctx
        ctx = ctx.baseContext
    }
    return null
}
