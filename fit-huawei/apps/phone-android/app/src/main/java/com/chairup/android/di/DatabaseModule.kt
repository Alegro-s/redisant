package com.chairup.android.di

import android.content.Context
import androidx.room.Room
import com.chairup.android.data.local.ChairUpDatabase
import com.chairup.android.data.local.dao.DailyAggregateDao
import com.chairup.android.data.local.dao.HealthDayDao
import com.chairup.android.data.local.dao.MicroSessionDao
import com.chairup.android.data.local.dao.StrengthWorkoutDao
import com.chairup.android.data.local.dao.UserProfileDao
import com.chairup.android.data.local.dao.WaistEntryDao
import com.chairup.android.data.local.dao.WeightEntryDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): ChairUpDatabase =
        Room.databaseBuilder(context, ChairUpDatabase::class.java, "chairup.db")
            .addMigrations(
                ChairUpDatabase.MIGRATION_1_2,
                ChairUpDatabase.MIGRATION_2_3,
                ChairUpDatabase.MIGRATION_3_4,
                ChairUpDatabase.MIGRATION_4_5,
            )
            .fallbackToDestructiveMigration()
            .build()

    @Provides
    fun provideMicroSessionDao(db: ChairUpDatabase): MicroSessionDao = db.microSessionDao()

    @Provides
    fun provideStrengthWorkoutDao(db: ChairUpDatabase): StrengthWorkoutDao = db.strengthWorkoutDao()

    @Provides
    fun provideWeightEntryDao(db: ChairUpDatabase): WeightEntryDao = db.weightEntryDao()

    @Provides
    fun provideWaistEntryDao(db: ChairUpDatabase): WaistEntryDao = db.waistEntryDao()

    @Provides
    fun provideHealthDayDao(db: ChairUpDatabase): HealthDayDao = db.healthDayDao()

    @Provides
    fun provideDailyDao(db: ChairUpDatabase): DailyAggregateDao = db.dailyAggregateDao()

    @Provides
    fun provideProfileDao(db: ChairUpDatabase): UserProfileDao = db.userProfileDao()
}
