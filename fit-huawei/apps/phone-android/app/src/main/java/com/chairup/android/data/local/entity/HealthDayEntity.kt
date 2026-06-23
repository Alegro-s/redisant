package com.chairup.android.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "health_day")
data class HealthDayEntity(
    @PrimaryKey val date: String,
    val steps: Int,
    val sleepMinutes: Int?,
    val restingHr: Int?,
    val syncedAt: Long,
)
