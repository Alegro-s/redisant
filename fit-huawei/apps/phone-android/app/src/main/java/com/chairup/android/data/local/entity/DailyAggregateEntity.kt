package com.chairup.android.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "daily_aggregate")
data class DailyAggregateEntity(
    @PrimaryKey val date: String,
    val steps: Int = 0,
    val stepsFromHms: Int = 0,
    val microDone: Int = 0,
    val microTarget: Int = 8,
    val proteinG: Float = 0f,
    val dailyScore: Float = 0f,
    val strengthDone: Boolean = false,
    val sleepMinutes: Int? = null,
    val restingHr: Int? = null,
    val updatedAt: Long = System.currentTimeMillis(),
)
