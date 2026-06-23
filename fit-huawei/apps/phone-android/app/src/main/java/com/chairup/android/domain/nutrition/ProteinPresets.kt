package com.chairup.android.domain.nutrition

data class ProteinPreset(
    val id: String,
    val label: String,
    val grams: Float,
)

object ProteinPresets {
    val all = listOf(
        ProteinPreset("eggs3", "3 яйца", 18f),
        ProteinPreset("cottage", "Творог 200г", 32f),
        ProteinPreset("chicken", "Курица 150г", 35f),
        ProteinPreset("shake", "Протеин", 25f),
        ProteinPreset("fish", "Рыба 150г", 30f),
        ProteinPreset("yogurt", "Греческий йогурт", 15f),
    )

    fun defaultTargetGrams(weightKg: Float): Float = (weightKg * 1.8f).coerceIn(120f, 220f)
}
