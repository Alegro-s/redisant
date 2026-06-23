package com.chairup.android.integration.health

import android.content.Intent
import com.chairup.android.domain.health.HealthMetrics
import com.chairup.android.domain.health.ImportedWorkout

interface HealthGateway {
    val isHmsConfigured: Boolean
    suspend fun getAuthState(): HealthAuthState
    fun createAuthorizeIntent(): Intent?
    suspend fun readMetrics(): Result<HealthMetrics>
    suspend fun readRecentWorkouts(sinceMillis: Long): Result<List<ImportedWorkout>>
    suspend fun readStepsSince(sinceMillis: Long): Result<Int>
}
