package com.chairup.android.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.chairup.android.data.local.entity.StrengthWorkoutEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface StrengthWorkoutDao {
    @Query("SELECT * FROM strength_workout WHERE date >= :fromDate ORDER BY completedAt DESC")
    fun observeSince(fromDate: String): Flow<List<StrengthWorkoutEntity>>

    @Query("SELECT COUNT(*) FROM strength_workout WHERE date >= :weekStart")
    suspend fun countSince(weekStart: String): Int

    @Query("SELECT * FROM strength_workout WHERE date = :date ORDER BY completedAt DESC LIMIT 1")
    suspend fun latestOnDate(date: String): StrengthWorkoutEntity?

    @Query("SELECT * FROM strength_workout ORDER BY completedAt DESC LIMIT 1")
    suspend fun getLatest(): StrengthWorkoutEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: StrengthWorkoutEntity)
}
