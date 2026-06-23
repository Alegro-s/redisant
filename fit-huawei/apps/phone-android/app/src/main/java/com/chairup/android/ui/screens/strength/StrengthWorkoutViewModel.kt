package com.chairup.android.ui.screens.strength

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.chairup.android.data.preferences.UserPreferencesRepository
import com.chairup.android.data.repository.StrengthExerciseUi
import com.chairup.android.data.repository.StrengthRepository
import com.chairup.android.domain.WaveProgression
import com.chairup.android.domain.strength.StrengthTemplateId
import com.chairup.android.domain.strength.StrengthTemplates
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class StrengthWorkoutUiState(
    val title: String = "",
    val exercises: List<StrengthExerciseUi> = emptyList(),
    val checkedSets: Map<String, List<Boolean>> = emptyMap(),
    val restSecondsLeft: Int? = null,
    val elapsedSec: Int = 0,
    val saving: Boolean = false,
    val error: String? = null,
    val allSetsDone: Boolean = false,
)

@HiltViewModel
class StrengthWorkoutViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val strengthRepository: StrengthRepository,
    private val preferences: UserPreferencesRepository,
) : ViewModel() {
    private val templateId: StrengthTemplateId =
        StrengthTemplateId.fromKey(savedStateHandle.get<String>("templateId") ?: "A")
            ?: StrengthTemplateId.A

    private val template = StrengthTemplates.byId(templateId)

    private val _state = MutableStateFlow(StrengthWorkoutUiState())
    val state: StateFlow<StrengthWorkoutUiState> = _state.asStateFlow()

    private var restJob: Job? = null
    private var elapsedJob: Job? = null
    private val startedAt = System.currentTimeMillis()

    init {
        viewModelScope.launch {
            val week = WaveProgression.weekNumber(preferences.installTimestamp.first())
            val exercises = strengthRepository.exerciseTargets(template, week)
            val checked = exercises.associate { it.exercise.id to List(it.sets) { false } }
            _state.value = StrengthWorkoutUiState(
                title = template.title,
                exercises = exercises,
                checkedSets = checked,
            )
            elapsedJob = viewModelScope.launch {
                while (true) {
                    delay(1000)
                    val elapsed = ((System.currentTimeMillis() - startedAt) / 1000).toInt()
                    _state.update { it.copy(elapsedSec = elapsed) }
                }
            }
        }
    }

    fun toggleSet(exerciseId: String, setIndex: Int) {
        val wasChecked = _state.value.checkedSets[exerciseId]?.getOrElse(setIndex) { false } == true
        _state.update { current ->
            val sets = current.checkedSets[exerciseId]?.toMutableList() ?: return@update current
            if (setIndex !in sets.indices) return@update current
            sets[setIndex] = !sets[setIndex]
            val updated = current.checkedSets + (exerciseId to sets)
            val allDone = updated.values.all { list -> list.all { it } }
            current.copy(checkedSets = updated, allSetsDone = allDone)
        }
        val nowChecked = _state.value.checkedSets[exerciseId]?.getOrElse(setIndex) { false } == true
        if (nowChecked && !wasChecked) {
            val sets = _state.value.checkedSets[exerciseId] ?: return
            val moreInExercise = sets.drop(setIndex + 1).any { !it }
            val moreExercises = _state.value.checkedSets.any { (id, list) ->
                id != exerciseId && list.any { !it }
            }
            if (moreInExercise || moreExercises) {
                startRest(60)
            }
        }
    }

    private fun startRest(seconds: Int) {
        restJob?.cancel()
        restJob = viewModelScope.launch {
            _state.update { it.copy(restSecondsLeft = seconds) }
            var left = seconds
            while (left > 0) {
                delay(1000)
                left -= 1
                _state.update { it.copy(restSecondsLeft = left) }
            }
            _state.update { it.copy(restSecondsLeft = null) }
        }
    }

    fun skipRest() {
        restJob?.cancel()
        _state.update { it.copy(restSecondsLeft = null) }
    }

    fun finish(onResult: (Result<Unit>) -> Unit) {
        viewModelScope.launch {
            _state.update { it.copy(saving = true, error = null) }
            val duration = _state.value.elapsedSec.coerceAtLeast(60)
            val result = strengthRepository.completeWorkout(templateId, duration)
            _state.update { it.copy(saving = false, error = result.exceptionOrNull()?.message) }
            onResult(result)
        }
    }

    override fun onCleared() {
        restJob?.cancel()
        elapsedJob?.cancel()
        super.onCleared()
    }
}
