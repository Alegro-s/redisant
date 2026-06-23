package com.chairup.android.ui.screens.today

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.chairup.android.data.repository.HealthRepository
import com.chairup.android.data.repository.MetricsUiState
import com.chairup.android.data.repository.MicroRepository
import com.chairup.android.data.repository.MicroUiState
import com.chairup.android.data.repository.StrengthRepository
import com.chairup.android.data.repository.StrengthUiState
import com.chairup.android.data.repository.TodayRepository
import com.chairup.android.data.repository.TodayUiState
import com.chairup.android.integration.wear.WearSyncManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject

data class TodayScreenState(
    val today: TodayUiState = TodayUiState(),
    val metrics: MetricsUiState = MetricsUiState(),
    val micro: MicroUiState = MicroUiState(),
    val strength: StrengthUiState = StrengthUiState(),
    val syncStatus: String = "",
)

@HiltViewModel
class TodayViewModel @Inject constructor(
    private val todayRepository: TodayRepository,
    private val healthRepository: HealthRepository,
    private val microRepository: MicroRepository,
    private val strengthRepository: StrengthRepository,
    private val wearSyncManager: WearSyncManager,
) : ViewModel() {

    private val syncMessage = MutableStateFlow("")

    val state: StateFlow<TodayScreenState> = combine(
        todayRepository.observeToday(),
        healthRepository.observeMetrics(),
        microRepository.observeMicroState(),
        strengthRepository.observeStrength(),
        syncMessage,
    ) { today, metrics, micro, strength, msg ->
        TodayScreenState(
            today = today.copy(
                steps = metrics.todaySteps,
                microDone = micro.microDone,
                microTarget = micro.microTarget,
                chairMode = micro.chairMode,
                dailyScore = today.dailyScore,
            ),
            metrics = metrics,
            micro = micro,
            strength = strength,
            syncStatus = msg,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = TodayScreenState(),
    )

    private val _isRefreshing = MutableStateFlow(false)
    val isRefreshing: StateFlow<Boolean> = _isRefreshing

    init {
        viewModelScope.launch {
            todayRepository.ensureSeedData()
            microRepository.ensureInitialized()
            refresh(showErrors = false)
        }
    }

    fun refresh(showErrors: Boolean = true) {
        viewModelScope.launch {
            _isRefreshing.value = true
            syncMessage.value = "Синхронизация…"
            val result = healthRepository.syncFromHealth()
            strengthRepository.tryImportFromHealth()
            microRepository.refreshDailyAggregateForToday()
            wearSyncManager.pushStateToWatch()
            _isRefreshing.value = false
            syncMessage.value = when {
                result.isSuccess -> formatSyncedAt(result.getOrNull()?.syncedAtMillis)
                showErrors -> result.exceptionOrNull()?.message ?: "Ошибка синка"
                else -> ""
            }
        }
    }

    fun setChairMode(enabled: Boolean) {
        viewModelScope.launch { microRepository.setChairMode(enabled) }
    }

    private fun formatSyncedAt(millis: Long?): String {
        if (millis == null || millis == 0L) return ""
        val fmt = SimpleDateFormat("HH:mm", Locale.getDefault())
        return "Обновлено ${fmt.format(Date(millis))}"
    }
}
