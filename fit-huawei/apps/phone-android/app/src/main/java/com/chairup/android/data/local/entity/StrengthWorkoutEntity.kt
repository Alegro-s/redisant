package com.chairup.android.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "strength_workout")
data class StrengthWorkoutEntity(
    @PrimaryKey val id: String,
    val date: String,
    val templateId: String,
    val durationSec: Int,
    val completedAt: Long,
    val fromHealthImport: Boolean = false,
)
