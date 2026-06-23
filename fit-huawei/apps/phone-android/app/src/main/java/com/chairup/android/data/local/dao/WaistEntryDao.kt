package com.chairup.android.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.chairup.android.data.local.entity.WaistEntryEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface WaistEntryDao {
    @Query("SELECT * FROM waist_entry ORDER BY recordedAt DESC LIMIT 1")
    fun observeLatest(): Flow<WaistEntryEntity?>

    @Query("SELECT * FROM waist_entry ORDER BY recordedAt DESC LIMIT 1")
    suspend fun getLatest(): WaistEntryEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entry: WaistEntryEntity)
}
