package com.chairup.android.ui.screens.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.chairup.android.data.backup.BackupExporter
import com.chairup.android.data.preferences.UserPreferencesRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val preferences: UserPreferencesRepository,
    private val backupExporter: BackupExporter,
) : ViewModel() {
    val dndEnabled: StateFlow<Boolean> = preferences.dndEnabled
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    private val _nudgeCountToday = MutableStateFlow(0)
    val nudgeCountToday: StateFlow<Int> = _nudgeCountToday.asStateFlow()

    private val _exportMessage = MutableStateFlow("")
    val exportMessage: StateFlow<String> = _exportMessage.asStateFlow()

    init {
        viewModelScope.launch {
            _nudgeCountToday.value = preferences.getNudgeCountToday()
        }
    }

    fun setDnd(enabled: Boolean) {
        viewModelScope.launch { preferences.setDnd(enabled) }
    }

    fun exportBackup(onReady: (String) -> Unit) {
        viewModelScope.launch {
            backupExporter.exportToJson()
                .onSuccess { onReady(it) }
                .onFailure { _exportMessage.value = it.message ?: "Ошибка экспорта" }
        }
    }

    fun writeBackup(uri: android.net.Uri, json: String) {
        viewModelScope.launch {
            backupExporter.writeToUri(uri, json)
                .onSuccess { _exportMessage.value = "Резервная копия сохранена" }
                .onFailure { _exportMessage.value = it.message ?: "Ошибка записи" }
        }
    }
}
