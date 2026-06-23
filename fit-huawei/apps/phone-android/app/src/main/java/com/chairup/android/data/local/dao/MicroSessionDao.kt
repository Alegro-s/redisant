package com.chairup.android.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.chairup.android.data.local.entity.MicroSessionEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface MicroSessionDao {
    @Query("SELECT * FROM micro_session WHERE date = :date ORDER BY slotIndex ASC")
    fun observeByDate(date: String): Flow<List<MicroSessionEntity>>

    @Query("SELECT COUNT(*) FROM micro_session WHERE date = :date")
    suspend fun countByDate(date: String): Int

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(session: MicroSessionEntity)
}
