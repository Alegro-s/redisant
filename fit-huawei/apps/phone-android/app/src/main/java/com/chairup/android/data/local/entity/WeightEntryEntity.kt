package com.chairup.android.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "weight_entry")
data class WeightEntryEntity(
    @PrimaryKey val id: String,
    val date: String,
    val weightKg: Float,
    val recordedAt: Long,
)
