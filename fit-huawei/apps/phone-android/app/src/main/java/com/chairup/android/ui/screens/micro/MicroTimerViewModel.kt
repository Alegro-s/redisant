package com.chairup.android.ui.screens.micro

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.chairup.android.data.repository.MicroRepository
import com.chairup.android.widget.ChairUpWidgetProvider
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class MicroTimerViewModel @Inject constructor(
    private val microRepository: MicroRepository,
    @ApplicationContext private val context: Context,
) : ViewModel() {
    fun complete(slotIndex: Int, durationSec: Int, onResult: (Result<Unit>) -> Unit) {
        viewModelScope.launch {
            val result = microRepository.completeMicroSession(slotIndex, durationSec, "phone")
            if (result.isSuccess) {
                ChairUpWidgetProvider.requestUpdate(context)
            }
            onResult(result)
        }
    }
}
