package com.chairup.android.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "user_profile")
data class UserProfileEntity(
    @PrimaryKey val id: String = "default",
    val startWeightKg: Float = 88f,
    val targetProteinG: Float = 158f,
    val baselineSteps: Int = 4000,
    val currentWave: Int = 0,
    val chairModeDefault: Boolean = true,
    val annoyanceLevel: String = "normal",
)
