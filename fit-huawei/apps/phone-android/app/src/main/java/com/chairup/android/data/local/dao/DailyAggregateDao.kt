package com.chairup.android.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.chairup.android.data.local.entity.DailyAggregateEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface DailyAggregateDao {
    @Query("SELECT * FROM daily_aggregate WHERE date = :date LIMIT 1")
    fun observeByDate(date: String): Flow<DailyAggregateEntity?>

    @Query("SELECT * FROM daily_aggregate WHERE date = :date LIMIT 1")
    suspend fun getByDate(date: String): DailyAggregateEntity?

    @Query("SELECT * FROM daily_aggregate WHERE date BETWEEN :fromDate AND :toDate ORDER BY date ASC")
    fun observeBetween(fromDate: String, toDate: String): Flow<List<DailyAggregateEntity>>

    @Query("SELECT COUNT(*) FROM daily_aggregate WHERE date BETWEEN :fromDate AND :toDate AND dailyScore >= :minScore")
    suspend fun countSuccessfulDays(fromDate: String, toDate: String, minScore: Float = 70f): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entity: DailyAggregateEntity)
}
