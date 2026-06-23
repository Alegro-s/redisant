package com.chairup.android.ui.screens.strength

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.chairup.android.ui.theme.ChairAccent
import com.chairup.android.ui.theme.ChairSurface

@Composable
fun StrengthWorkoutScreen(
    onDone: () -> Unit,
    onCancel: () -> Unit,
    viewModel: StrengthWorkoutViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(state.title, style = MaterialTheme.typography.headlineMedium)
        Text(
            formatElapsed(state.elapsedSec),
            style = MaterialTheme.typography.titleLarge,
            color = ChairAccent,
            fontWeight = FontWeight.Bold,
        )

        state.restSecondsLeft?.let { rest ->
            Card(
                colors = CardDefaults.cardColors(containerColor = ChairAccent.copy(alpha = 0.15f)),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("Отдых", style = MaterialTheme.typography.titleMedium)
                    Text(
                        formatElapsed(rest),
                        style = MaterialTheme.typography.displaySmall,
                        color = ChairAccent,
                    )
                    OutlinedButton(onClick = viewModel::skipRest) {
                        Text("Пропустить")
                    }
                }
            }
        }

        state.exercises.forEach { item ->
            Card(
                colors = CardDefaults.cardColors(containerColor = ChairSurface),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.padding(12.dp)) {
                    val unit = if (item.exercise.id == "plank") "сек" else "повт"
                    Text(
                        "${item.exercise.name} · ${item.targetReps} $unit",
                        style = MaterialTheme.typography.titleMedium,
                    )
                    item.exercise.hint.takeIf { it.isNotEmpty() }?.let {
                        Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    val checked = state.checkedSets[item.exercise.id] ?: emptyList()
                    repeat(item.sets) { index ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Checkbox(
                                checked = checked.getOrElse(index) { false },
                                onCheckedChange = { viewModel.toggleSet(item.exercise.id, index) },
                            )
                            Text("Подход ${index + 1}")
                        }
                    }
                }
            }
        }

        Spacer(Modifier.height(8.dp))
        Button(
            onClick = {
                viewModel.finish { result ->
                    result.onSuccess { onDone() }
                }
            },
            enabled = state.allSetsDone && !state.saving,
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(20.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ChairAccent),
        ) {
            Text(if (state.saving) "Сохраняю…" else "Завершить тренировку")
        }
        OutlinedButton(onClick = onCancel, modifier = Modifier.fillMaxWidth()) {
            Text("Отмена")
        }
        state.error?.let {
            Text(it, color = MaterialTheme.colorScheme.error)
        }
    }
}

private fun formatElapsed(sec: Int): String {
    val m = sec / 60
    val s = sec % 60
    return "%d:%02d".format(m, s)
}
