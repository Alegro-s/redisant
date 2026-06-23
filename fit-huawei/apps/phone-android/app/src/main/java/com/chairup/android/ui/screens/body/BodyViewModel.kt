package com.chairup.android.ui.screens.body

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.chairup.android.data.preferences.UserPreferencesRepository
import com.chairup.android.data.repository.NutritionRepository
import com.chairup.android.data.repository.NutritionUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class BodyViewModel @Inject constructor(
    private val nutritionRepository: NutritionRepository,
    preferences: UserPreferencesRepository,
) : ViewModel() {
    val state: StateFlow<NutritionUiState> = nutritionRepository
        .observeNutrition(preferences.installTimestamp)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), NutritionUiState())

    fun addPreset(grams: Float) {
        viewModelScope.launch { nutritionRepository.addProtein(grams) }
    }

    fun copyYesterday() {
        viewModelScope.launch { nutritionRepository.copyProteinFromYesterday() }
    }

    fun logWeight(kg: Float) {
        viewModelScope.launch { nutritionRepository.logWeight(kg) }
    }

    fun logWaist(cm: Float) {
        viewModelScope.launch { nutritionRepository.logWaist(cm) }
    }
}
