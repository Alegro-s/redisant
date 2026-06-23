package com.chairup.android.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.chairup.android.data.local.dao.DailyAggregateDao
import com.chairup.android.data.local.dao.HealthDayDao
import com.chairup.android.data.local.dao.MicroSessionDao
import com.chairup.android.data.local.dao.StrengthWorkoutDao
import com.chairup.android.data.local.dao.UserProfileDao
import com.chairup.android.data.local.dao.WaistEntryDao
import com.chairup.android.data.local.dao.WeightEntryDao
import com.chairup.android.data.local.entity.DailyAggregateEntity
import com.chairup.android.data.local.entity.HealthDayEntity
import com.chairup.android.data.local.entity.MicroSessionEntity
import com.chairup.android.data.local.entity.StrengthWorkoutEntity
import com.chairup.android.data.local.entity.UserProfileEntity
import com.chairup.android.data.local.entity.WaistEntryEntity
import com.chairup.android.data.local.entity.WeightEntryEntity

@Database(
    entities = [
        DailyAggregateEntity::class,
        UserProfileEntity::class,
        HealthDayEntity::class,
        MicroSessionEntity::class,
        WeightEntryEntity::class,
        WaistEntryEntity::class,
        StrengthWorkoutEntity::class,
    ],
    version = 5,
    exportSchema = false,
)
abstract class ChairUpDatabase : RoomDatabase() {
    abstract fun dailyAggregateDao(): DailyAggregateDao
    abstract fun userProfileDao(): UserProfileDao
    abstract fun healthDayDao(): HealthDayDao
    abstract fun microSessionDao(): MicroSessionDao
    abstract fun weightEntryDao(): WeightEntryDao
    abstract fun waistEntryDao(): WaistEntryDao
    abstract fun strengthWorkoutDao(): StrengthWorkoutDao

    companion object {
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS health_day (
                        date TEXT NOT NULL PRIMARY KEY,
                        steps INTEGER NOT NULL,
                        sleepMinutes INTEGER,
                        restingHr INTEGER,
                        syncedAt INTEGER NOT NULL
                    )
                    """.trimIndent(),
                )
            }
        }

        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS micro_session (
                        id TEXT NOT NULL PRIMARY KEY,
                        date TEXT NOT NULL,
                        slotIndex INTEGER NOT NULL,
                        durationSec INTEGER NOT NULL,
                        completedAt INTEGER NOT NULL,
                        source TEXT NOT NULL
                    )
                    """.trimIndent(),
                )
                db.execSQL(
                    "CREATE UNIQUE INDEX IF NOT EXISTS index_micro_session_date_slotIndex ON micro_session(date, slotIndex)",
                )
            }
        }

        val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS strength_workout (
                        id TEXT NOT NULL PRIMARY KEY,
                        date TEXT NOT NULL,
                        templateId TEXT NOT NULL,
                        durationSec INTEGER NOT NULL,
                        completedAt INTEGER NOT NULL,
                        fromHealthImport INTEGER NOT NULL DEFAULT 0
                    )
                    """.trimIndent(),
                )
            }
        }

        val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS weight_entry (
                        id TEXT NOT NULL PRIMARY KEY,
                        date TEXT NOT NULL,
                        weightKg REAL NOT NULL,
                        recordedAt INTEGER NOT NULL
                    )
                    """.trimIndent(),
                )
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS waist_entry (
                        id TEXT NOT NULL PRIMARY KEY,
                        date TEXT NOT NULL,
                        waistCm REAL NOT NULL,
                        recordedAt INTEGER NOT NULL
                    )
                    """.trimIndent(),
                )
            }
        }
    }
}
