package com.chairup.android.domain.coach

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import java.time.LocalTime
import javax.inject.Inject
import javax.inject.Singleton

data class CoachContext(
    val chairMode: Boolean,
    val microDone: Int,
    val microTarget: Int,
    val stepsLast45Min: Int,
    val proteinRatio: Float,
    val dnd: Boolean,
    val celebratedToday: Boolean,
    val hour: Int = LocalTime.now().hour,
)

data class CoachAction(
    val ruleId: String,
    val action: String,
    val channel: String,
    val title: String,
    val message: String,
)

@Singleton
class CoachEngine @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private val rules: List<CoachRule> by lazy { CoachRuleLoader.load(context, "coach/neat-v1.yaml") }

    fun evaluate(ctx: CoachContext): List<CoachAction> {
        val matched = rules.filter { it.matches(ctx) }.sortedBy { it.priority }
        return matched.map { rule ->
            CoachAction(
                ruleId = rule.id,
                action = rule.action,
                channel = rule.channel,
                title = rule.titleFor(ctx),
                message = rule.message,
            )
        }
    }
}

private data class CoachRule(
    val id: String,
    val priority: Int,
    val action: String,
    val channel: String,
    val message: String,
    val cooldownMinutes: Int,
    private val conditions: List<(CoachContext) -> Boolean>,
) {
    fun matches(ctx: CoachContext): Boolean = conditions.all { it(ctx) }

    fun titleFor(ctx: CoachContext): String = when (id) {
        "protein_evening" -> "Coach: белок"
        "celebrate_micro_complete" -> "8/8 микро"
        else -> "Coach: активность"
    }
}

private object CoachRuleLoader {
    fun load(context: Context, assetPath: String): List<CoachRule> {
        val text = context.assets.open(assetPath).bufferedReader().readText()
        return parseRules(text)
    }

    private fun parseRules(yaml: String): List<CoachRule> {
        val rules = mutableListOf<CoachRule>()
        val blocks = yaml.split(Regex("(?=^  - id: )", RegexOption.MULTILINE)).drop(1)
        for (block in blocks) {
            val id = Regex("id: (\\S+)").find(block)?.groupValues?.get(1) ?: continue
            val priority = Regex("priority: (\\d+)").find(block)?.groupValues?.get(1)?.toIntOrNull() ?: 50
            val action = Regex("action: (\\S+)").find(block)?.groupValues?.get(1) ?: "notify"
            val channel = Regex("channel: (\\S+)").find(block)?.groupValues?.get(1) ?: "phone"
            val message = Regex("message_ru: \"(.+)\"").find(block)?.groupValues?.get(1) ?: continue
            val cooldown = Regex("cooldown_minutes: (\\d+)").find(block)?.groupValues?.get(1)?.toIntOrNull() ?: 45
            val conditions = parseConditions(block)
            rules.add(CoachRule(id, priority, action, channel, message, cooldown, conditions))
        }
        return rules
    }

    private fun parseConditions(block: String): List<(CoachContext) -> Boolean> {
        val list = mutableListOf<(CoachContext) -> Boolean>()
        if (block.contains("chair_mode: true")) {
            list.add { it.chairMode }
        }
        if (block.contains("dnd: false")) {
            list.add { !it.dnd }
        }
        if (block.contains("celebrated_today: false")) {
            list.add { !it.celebratedToday }
        }
        Regex("micro_done_today: \\{ gte: (\\d+) \\}").find(block)?.let { m ->
            val min = m.groupValues[1].toInt()
            list.add { it.microDone >= min }
        }
        Regex("micro_done_today: \\{ lt: (\\d+) \\}").find(block)?.let { m ->
            val max = m.groupValues[1].toInt()
            list.add { it.microDone < max }
        }
        Regex("hour: \\{ gte: (\\d+) \\}").find(block)?.let { m ->
            val min = m.groupValues[1].toInt()
            list.add { it.hour >= min }
        }
        Regex("protein_ratio: \\{ lt: ([\\d.]+) \\}").find(block)?.let { m ->
            val max = m.groupValues[1].toFloat()
            list.add { it.proteinRatio < max }
        }
        Regex("steps_last_45min: \\{ lt: (\\d+) \\}").find(block)?.let { m ->
            val max = m.groupValues[1].toInt()
            list.add { it.stepsLast45Min < max }
        }
        return list
    }
}
