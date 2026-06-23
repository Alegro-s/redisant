package com.chairup.android.integration.wear

interface WearBridge {
    suspend fun sendState(state: WearStatePush): Result<Unit>
    suspend fun sendStartMicro(slotIndex: Int, targetSec: Int = 120): Result<Unit>
    fun setMessageListener(listener: (WearMicroDone) -> Unit)
}
