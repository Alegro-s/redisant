package com.chairup.android.domain.coach

import org.junit.Assert.assertTrue
import org.junit.Test

class CoachEngineTest {

    @Test
    fun sedentaryRule_firesWhenLowSteps() {
        val rules = listOf(
            rule(
                id = "sedentary_nudge",
                priority = 10,
                message = "2 минуты",
                conditions = listOf(
                    { it.chairMode },
                    { !it.dnd },
                    { it.stepsLast45Min < 80 },
                    { it.microDone < it.microTarget },
                ),
            ),
        )
        val actions = evaluateRules(
            rules,
            CoachContext(
                chairMode = true,
                microDone = 2,
                microTarget = 8,
                stepsLast45Min = 30,
                proteinRatio = 0.8f,
                dnd = false,
                celebratedToday = false,
                hour = 14,
            ),
        )
        assertTrue(actions.any { it.ruleId == "sedentary_nudge" })
    }

    @Test
    fun proteinRule_firesInEvening() {
        val rules = listOf(
            rule(
                id = "protein_evening",
                priority = 30,
                message = "Белок",
                conditions = listOf(
                    { it.hour >= 19 },
                    { it.proteinRatio < 0.6f },
                ),
            ),
        )
        val actions = evaluateRules(
            rules,
            CoachContext(
                chairMode = true,
                microDone = 4,
                microTarget = 8,
                stepsLast45Min = 200,
                proteinRatio = 0.4f,
                dnd = false,
                celebratedToday = false,
                hour = 20,
            ),
        )
        assertTrue(actions.any { it.ruleId == "protein_evening" })
    }

    private data class TestRule(
        val id: String,
        val priority: Int,
        val message: String,
        val conditions: List<(CoachContext) -> Boolean>,
    )

    private fun rule(
        id: String,
        priority: Int,
        message: String,
        conditions: List<(CoachContext) -> Boolean>,
    ) = TestRule(id, priority, message, conditions)

    private fun evaluateRules(rules: List<TestRule>, ctx: CoachContext): List<CoachAction> =
        rules.filter { r -> r.conditions.all { it(ctx) } }
            .sortedBy { it.priority }
            .map {
                CoachAction(
                    ruleId = it.id,
                    action = "notify",
                    channel = "phone",
                    title = it.id,
                    message = it.message,
                )
            }
}
