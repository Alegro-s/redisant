package com.chairup.android.ui.screens.coach

import androidx.lifecycle.ViewModel
import com.chairup.android.data.repository.CoachRepository
import com.chairup.android.data.repository.WeeklyReportUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import androidx.lifecycle.viewModelScope
import javax.inject.Inject

@HiltViewModel
class WeeklyReportViewModel @Inject constructor(
    coachRepository: CoachRepository,
) : ViewModel() {
    val report: StateFlow<WeeklyReportUiState> = coachRepository.observeWeeklyReport()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), WeeklyReportUiState())
}
