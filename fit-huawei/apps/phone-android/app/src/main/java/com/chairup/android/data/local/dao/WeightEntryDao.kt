package com.chairup.android.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.chairup.android.data.local.entity.WeightEntryEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface WeightEntryDao {
    @Query("SELECT * FROM weight_entry ORDER BY date DESC, recordedAt DESC LIMIT :limit")
    fun observeRecent(limit: Int = 60): Flow<List<WeightEntryEntity>>

    @Query("SELECT * FROM weight_entry ORDER BY date ASC")
    suspend fun getAllAscending(): List<WeightEntryEntity>

    @Query("SELECT * FROM weight_entry WHERE date = :date ORDER BY recordedAt DESC LIMIT 1")
    suspend fun latestOnDate(date: String): WeightEntryEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entry: WeightEntryEntity)
}
