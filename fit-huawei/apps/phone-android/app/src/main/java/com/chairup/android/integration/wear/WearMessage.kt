package com.chairup.android.integration.wear

import org.json.JSONObject

data class WearStatePush(
    val dailyScore: Float,
    val microDone: Int,
    val microTarget: Int,
    val nextSlotInMin: Int,
    val chairMode: Boolean,
)

data class WearMicroDone(
    val slotIndex: Int,
    val durationSec: Int,
)

object WearMessageCodec {
    private const val V = 1

    fun encodeState(state: WearStatePush): String = JSONObject()
        .put("v", V)
        .put("type", "STATE_PUSH")
        .put("ts", System.currentTimeMillis())
        .put("dailyScore", state.dailyScore)
        .put("microDone", state.microDone)
        .put("microTarget", state.microTarget)
        .put("nextSlotInMin", state.nextSlotInMin)
        .put("chairMode", state.chairMode)
        .toString()

    fun decode(raw: String): WearMicroDone? = runCatching {
        val json = JSONObject(raw)
        if (json.optInt("v") != V) return null
        if (json.optString("type") != "MICRO_DONE") return null
        WearMicroDone(
            slotIndex = json.getInt("slotIndex"),
            durationSec = json.getInt("durationSec"),
        )
    }.getOrNull()
}
