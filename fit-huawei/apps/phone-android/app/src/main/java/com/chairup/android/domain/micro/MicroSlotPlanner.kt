package com.chairup.android.domain.micro

import java.time.LocalDate
import java.time.LocalTime

data class MicroSlot(
    val index: Int,
    val scheduledTime: LocalTime,
    val label: String,
)

object MicroSlotPlanner {
    /** 8 слотов с 10:00 до ~19:30 (шаг ~75 мин). */
    fun slotsForToday(targetCount: Int = 8): List<MicroSlot> {
        val count = targetCount.coerceIn(1, 8)
        val start = LocalTime.of(10, 0)
        val end = LocalTime.of(19, 30)
        val totalMinutes = end.toSecondOfDay() / 60 - start.toSecondOfDay() / 60
        val step = if (count <= 1) 0 else totalMinutes / (count - 1)
        return (0 until count).map { i ->
            val minutes = start.toSecondOfDay() / 60 + step * i
            val time = LocalTime.ofSecondOfDay(minutes.toLong() * 60)
            MicroSlot(
                index = i,
                scheduledTime = time,
                label = time.toString().substring(0, 5),
            )
        }
    }

    fun nextSlot(
        slots: List<MicroSlot>,
        completedIndices: Set<Int>,
        now: LocalTime = LocalTime.now(),
    ): MicroSlot? {
        val pending = slots.filter { it.index !in completedIndices }
        if (pending.isEmpty()) return null
        return pending.firstOrNull { it.scheduledTime >= now } ?: pending.last()
    }

    fun minutesUntil(slot: MicroSlot, now: LocalTime = LocalTime.now()): Int {
        val nowMin = now.toSecondOfDay() / 60
        val slotMin = slot.scheduledTime.toSecondOfDay() / 60
        return (slotMin - nowMin).coerceAtLeast(0)
    }
}
