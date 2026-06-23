package com.chairup.android.domain

import com.chairup.android.data.local.entity.WeightEntryEntity
import kotlin.math.roundToInt

data class WeightPoint(
    val date: String,
    val kg: Float,
    val ma7: Float?,
)

object WeightTrend {
    fun movingAverage7(entries: List<WeightEntryEntity>): List<WeightPoint> {
        if (entries.isEmpty()) return emptyList()
        val byDate = entries
            .groupBy { it.date }
            .map { (date, list) -> date to list.maxBy { it.recordedAt }.weightKg }
            .sortedBy { it.first }
        return byDate.mapIndexed { index, (date, kg) ->
            val window = byDate.subList(maxOf(0, index - 6), index + 1).map { it.second }
            val ma = window.average().toFloat()
            WeightPoint(date, kg, ma)
        }
    }

    fun trendRatio(entries: List<WeightEntryEntity>, startWeightKg: Float): Float {
        val points = movingAverage7(entries)
        if (points.size < 2) return 0.5f
        val latest = points.last().ma7 ?: points.last().kg
        val first = points.first().ma7 ?: points.first().kg
        val delta = latest - first
        return when {
            delta <= -0.3f -> 1f
            delta <= 0.2f -> 0.7f
            else -> 0.3f
        }
    }

    fun formatKg(kg: Float): String = "${(kg * 10).roundToInt() / 10f} кг"
}
