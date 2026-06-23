package com.chairup.android.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.chairup.android.data.local.entity.HealthDayEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface HealthDayDao {
    @Query("SELECT * FROM health_day ORDER BY date ASC")
    fun observeAll(): Flow<List<HealthDayEntity>>

    @Query("SELECT * FROM health_day ORDER BY date ASC")
    suspend fun getAll(): List<HealthDayEntity>

    @Query("SELECT * FROM health_day WHERE date = :date LIMIT 1")
    suspend fun getByDate(date: String): HealthDayEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(rows: List<HealthDayEntity>)

    @Query("SELECT MAX(syncedAt) FROM health_day")
    suspend fun lastSyncedAt(): Long?
}
