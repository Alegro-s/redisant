package com.chairup.android.ui.screens.health

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.chairup.android.BuildConfig
import com.chairup.android.integration.health.HealthAuthState
import com.chairup.android.integration.health.HealthGateway
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HealthUiState(
    val hmsEnabled: Boolean = BuildConfig.HMS_ENABLED,
    val authState: HealthAuthState = HealthAuthState.Unknown,
    val statusMessage: String = "",
)

@HiltViewModel
class HealthViewModel @Inject constructor(
    private val healthGateway: HealthGateway,
) : ViewModel() {
    private val _state = MutableStateFlow(HealthUiState())
    val state: StateFlow<HealthUiState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            val auth = healthGateway.getAuthState()
            _state.update {
                it.copy(
                    authState = auth,
                    hmsEnabled = healthGateway.isHmsConfigured,
                    statusMessage = when {
                        !healthGateway.isHmsConfigured ->
                            "Скопируйте agconnect-services.json в app/ и пересоберите APK"
                        auth is HealthAuthState.Authorized ->
                            "Health Kit готов к чтению шагов, сна и пульса"
                        else -> "Нажмите кнопку ниже для OAuth"
                    },
                )
            }
        }
    }

    fun prepareAuthorizeIntent() = healthGateway.createAuthorizeIntent()
}
