package com.chairup.android.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "waist_entry")
data class WaistEntryEntity(
    @PrimaryKey val id: String,
    val date: String,
    val waistCm: Float,
    val recordedAt: Long,
)
