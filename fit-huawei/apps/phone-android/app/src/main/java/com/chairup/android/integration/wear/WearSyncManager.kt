package com.chairup.android.integration.wear

import com.chairup.android.data.repository.MicroRepository
import com.chairup.android.data.repository.TodayRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class WearSyncManager @Inject constructor(
    private val wearBridge: WearBridge,
    private val microRepository: MicroRepository,
    private val todayRepository: TodayRepository,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    fun start() {
        wearBridge.setMessageListener { done ->
            scope.launch {
                microRepository.completeMicroSession(
                    slotIndex = done.slotIndex,
                    durationSec = done.durationSec.coerceAtLeast(60),
                    source = "watch",
                )
                pushStateToWatch()
            }
        }
    }

    suspend fun pushStateToWatch() {
        val micro = microRepository.observeMicroState().first()
        val today = todayRepository.observeToday().first()
        wearBridge.sendState(
            WearStatePush(
                dailyScore = today.dailyScore,
                microDone = micro.microDone,
                microTarget = micro.microTarget,
                nextSlotInMin = micro.nextSlotInMin,
                chairMode = micro.chairMode,
            ),
        )
    }

    suspend fun startMicroOnWatch(slotIndex: Int) {
        wearBridge.sendStartMicro(slotIndex)
    }
}
