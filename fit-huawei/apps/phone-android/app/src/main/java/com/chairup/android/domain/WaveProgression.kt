package com.chairup.android.domain

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

object WaveProgression {
    fun weekNumber(installMillis: Long, zone: ZoneId = ZoneId.systemDefault()): Int {
        val install = Instant.ofEpochMilli(installMillis).atZone(zone).toLocalDate()
        val days = ChronoUnit.DAYS.between(install, LocalDate.now(zone)).toInt()
        return (days / 7 + 1).coerceIn(1, 4)
    }

    fun microTargetForWeek(week: Int): Int = when (week.coerceIn(1, 4)) {
        1 -> 4
        2 -> 5
        3 -> 6
        else -> 8
    }

    fun stepBonusForWeek(week: Int): Int = when (week.coerceIn(1, 4)) {
        1 -> 0
        2 -> 300
        3 -> 600
        else -> 1000
    }
}
