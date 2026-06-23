package com.chairup.android.data.repository

import com.chairup.android.data.local.dao.DailyAggregateDao
import com.chairup.android.data.local.dao.UserProfileDao
import com.chairup.android.data.local.dao.WeightEntryDao
import com.chairup.android.data.local.entity.DailyAggregateEntity
import com.chairup.android.data.local.entity.UserProfileEntity
import com.chairup.android.data.local.entity.WeightEntryEntity
import com.chairup.android.domain.nutrition.ProteinPresets
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

data class TodayUiState(
    val date: String = "",
    val dailyScore: Float = 0f,
    val microDone: Int = 0,
    val microTarget: Int = 4,
    val steps: Int = 0,
    val proteinG: Float = 0f,
    val proteinTargetG: Float = 158f,
    val wave: Int = 4,
    val chairMode: Boolean = true,
)

@Singleton
class TodayRepository @Inject constructor(
    private val dailyDao: DailyAggregateDao,
    private val profileDao: UserProfileDao,
    private val weightDao: WeightEntryDao,
) {
    private val dateFmt = DateTimeFormatter.ISO_LOCAL_DATE

    fun observeToday(): Flow<TodayUiState> {
        val today = LocalDate.now().format(dateFmt)
        return combine(
            dailyDao.observeByDate(today),
            profileDao.observeProfile(),
        ) { entity, profile ->
            val row = entity ?: DailyAggregateEntity(date = today)
            val p = profile ?: UserProfileEntity()
            val target = p.targetProteinG.takeIf { it > 0 }
                ?: ProteinPresets.defaultTargetGrams(p.startWeightKg)
            TodayUiState(
                date = today,
                dailyScore = row.dailyScore,
                microDone = row.microDone,
                microTarget = row.microTarget,
                steps = row.stepsFromHms.takeIf { it > 0 } ?: row.steps,
                proteinG = row.proteinG,
                proteinTargetG = target,
                wave = 4,
                chairMode = true,
            )
        }
    }

    suspend fun ensureSeedData() {
        val today = LocalDate.now().format(dateFmt)
        profileDao.upsert(
            UserProfileEntity(
                currentWave = 4,
                startWeightKg = 88f,
                targetProteinG = ProteinPresets.defaultTargetGrams(88f),
            ),
        )
        if (dailyDao.getByDate(today) == null) {
            dailyDao.upsert(DailyAggregateEntity(date = today, microTarget = 4))
        }
        if (weightDao.getAllAscending().isEmpty()) {
            weightDao.insert(
                WeightEntryEntity(
                    id = UUID.randomUUID().toString(),
                    date = today,
                    weightKg = 88f,
                    recordedAt = System.currentTimeMillis(),
                ),
            )
        }
    }
}
