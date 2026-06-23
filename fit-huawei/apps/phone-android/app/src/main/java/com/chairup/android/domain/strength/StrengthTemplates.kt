package com.chairup.android.domain.strength

object StrengthTemplates {
    val templateA = StrengthTemplate(
        id = StrengthTemplateId.A,
        title = "Шаблон A",
        subtitle = "Дом · без инвентаря",
        minutesLabel = "~25 мин",
        exercises = listOf(
            StrengthExercise("pushup", "Отжимания", baseReps = 8, hint = "колени ок"),
            StrengthExercise("squat", "Приседания", baseReps = 12),
            StrengthExercise("plank", "Планка", baseReps = 40, hint = "секунды"),
        ),
    )

    val templateB = StrengthTemplate(
        id = StrengthTemplateId.B,
        title = "Шаблон B",
        subtitle = "Резина / выпады",
        minutesLabel = "~30 мин",
        exercises = listOf(
            StrengthExercise("lunge", "Выпады", baseReps = 10, hint = "на ногу"),
            StrengthExercise("band_row", "Тяга резиной", baseReps = 12),
            StrengthExercise("glute_bridge", "Ягодичный мост", baseReps = 15),
        ),
    )

    fun all(): List<StrengthTemplate> = listOf(templateA, templateB)

    fun byId(id: StrengthTemplateId): StrengthTemplate = when (id) {
        StrengthTemplateId.A -> templateA
        StrengthTemplateId.B -> templateB
    }
}
