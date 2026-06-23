package com.chairup.android.domain

import com.chairup.android.data.local.entity.DailyAggregateEntity
import org.junit.Assert.assertEquals
import org.junit.Test

class DailyScoreCalculatorTest {
    @Test
    fun `zero activity gives baseline from weight trend`() {
        val entity = DailyAggregateEntity(date = "2026-05-20", microDone = 0, microTarget = 8)
        assertEquals(5f, DailyScoreCalculator.calculate(entity, 8000, 158f), 0.01f)
    }

    @Test
    fun `full day including strength gives perfect score`() {
        val entity = DailyAggregateEntity(
            date = "2026-05-20",
            microDone = 8,
            microTarget = 8,
            steps = 8000,
            stepsFromHms = 8000,
            proteinG = 158f,
            strengthDone = true,
        )
        assertEquals(
            100f,
            DailyScoreCalculator.calculate(entity, 8000, 158f, weightTrendRatio = 1f),
            0.01f,
        )
    }

    @Test
    fun `micro only half`() {
        val entity = DailyAggregateEntity(date = "2026-05-20", microDone = 4, microTarget = 8)
        val score = DailyScoreCalculator.calculate(entity, 8000, 158f)
        assertEquals(25f, score, 1f)
    }

    @Test
    fun `strength alone adds ten points`() {
        val entity = DailyAggregateEntity(date = "2026-05-20", strengthDone = true)
        assertEquals(15f, DailyScoreCalculator.calculate(entity, 8000, 158f), 0.01f)
    }
}
