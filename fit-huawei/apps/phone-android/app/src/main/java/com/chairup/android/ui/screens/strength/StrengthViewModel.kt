package com.chairup.android.ui.screens.strength

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.chairup.android.data.repository.StrengthRepository
import com.chairup.android.data.repository.StrengthUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class StrengthViewModel @Inject constructor(
    repository: StrengthRepository,
) : ViewModel() {
    val state: StateFlow<StrengthUiState> = repository
        .observeStrength()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), StrengthUiState())
}
