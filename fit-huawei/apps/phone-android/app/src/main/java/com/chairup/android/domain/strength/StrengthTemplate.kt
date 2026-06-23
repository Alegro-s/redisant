package com.chairup.android.domain.strength

enum class StrengthTemplateId(val key: String) {
    A("A"),
    B("B"),
    ;

    companion object {
        fun fromKey(key: String): StrengthTemplateId? =
            entries.firstOrNull { it.key.equals(key, ignoreCase = true) }
    }
}

data class StrengthTemplate(
    val id: StrengthTemplateId,
    val title: String,
    val subtitle: String,
    val minutesLabel: String,
    val exercises: List<StrengthExercise>,
)
