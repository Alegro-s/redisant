package com.chairup.android.domain



import com.chairup.android.data.local.entity.DailyAggregateEntity



object DailyScoreCalculator {

    /**

     * Wave 4: микро + шаги + белок + тренд веса + силовая (100%).

     */

    fun calculate(

        entity: DailyAggregateEntity,

        stepGoal: Int,

        proteinTargetG: Float,

        weightTrendRatio: Float = 0.5f,

        strengthDone: Boolean = entity.strengthDone,

    ): Float {

        val microRatio = if (entity.microTarget > 0) {

            entity.microDone.toFloat() / entity.microTarget

        } else {

            0f

        }

        val steps = entity.stepsFromHms.takeIf { it > 0 } ?: entity.steps

        val stepsRatio = if (stepGoal > 0) {

            (steps.toFloat() / stepGoal).coerceIn(0f, 1f)

        } else {

            0f

        }

        val proteinRatio = if (proteinTargetG > 0) {

            (entity.proteinG / proteinTargetG).coerceIn(0f, 1f)

        } else {

            0f

        }

        val strengthRatio = if (strengthDone) 1f else 0f

        val score = 0.40f * microRatio +

            0.20f * stepsRatio +

            0.20f * proteinRatio +

            0.10f * weightTrendRatio.coerceIn(0f, 1f) +

            0.10f * strengthRatio

        return (score * 100f).coerceIn(0f, 100f)

    }

}

