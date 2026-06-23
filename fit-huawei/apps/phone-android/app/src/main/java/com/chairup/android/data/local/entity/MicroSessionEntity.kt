package com.chairup.android.data.local.entity

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "micro_session",
    indices = [Index(value = ["date", "slotIndex"], unique = true)],
)
data class MicroSessionEntity(
    @PrimaryKey val id: String,
    val date: String,
    val slotIndex: Int,
    val durationSec: Int,
    val completedAt: Long,
    val source: String,
)
