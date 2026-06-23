package com.chairup.android.ui.screens.body

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.chairup.android.domain.WeightTrend
import com.chairup.android.ui.components.WeightTrendChart
import com.chairup.android.ui.theme.ChairAccent
import com.chairup.android.ui.theme.ChairSurface
import com.chairup.android.ui.theme.ChairWarning

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun BodyScreen(
    viewModel: BodyViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var weightInput by remember(state.latestWeightKg) {
        mutableStateOf(state.latestWeightKg?.toString() ?: state.startWeightKg.toString())
    }
    var waistInput by remember(state.latestWaistCm) {
        mutableStateOf(state.latestWaistCm?.toString() ?: "")
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("Тело", style = MaterialTheme.typography.headlineMedium)
        Text(
            "Wave 3 · белок и вес без занудного подсчёта калорий",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Card(colors = CardDefaults.cardColors(containerColor = ChairSurface), shape = RoundedCornerShape(20.dp)) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text("Белок", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "${state.proteinG.toInt()} / ${state.proteinTargetG.toInt()} г",
                        color = ChairAccent,
                    )
                }
                LinearProgressIndicator(
                    progress = { state.proteinRatio },
                    modifier = Modifier.fillMaxWidth(),
                    color = ChairAccent,
                )
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    state.presets.forEach { preset ->
                        FilterChip(
                            selected = false,
                            onClick = { viewModel.addPreset(preset.grams) },
                            label = { Text("${preset.label} +${preset.grams.toInt()}г") },
                        )
                    }
                }
                OutlinedButton(onClick = viewModel::copyYesterday, modifier = Modifier.fillMaxWidth()) {
                    Text("Как вчера")
                }
            }
        }

        state.calorieHint?.let {
            Text(it, color = ChairWarning, style = MaterialTheme.typography.bodyLarge)
        }

        Card(colors = CardDefaults.cardColors(containerColor = ChairSurface), shape = RoundedCornerShape(20.dp)) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Вес", style = MaterialTheme.typography.titleMedium)
                state.latestWeightKg?.let {
                    Text("Сейчас: ${WeightTrend.formatKg(it)}", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                OutlinedTextField(
                    value = weightInput,
                    onValueChange = { weightInput = it },
                    label = { Text("кг") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                Button(
                    onClick = {
                        weightInput.replace(',', '.').toFloatOrNull()?.let(viewModel::logWeight)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = ChairAccent),
                ) {
                    Text("Сохранить вес")
                }
                WeightTrendChart(state.weightPoints)
            }
        }

        Card(colors = CardDefaults.cardColors(containerColor = ChairSurface), shape = RoundedCornerShape(20.dp)) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Талия", style = MaterialTheme.typography.titleMedium)
                if (state.waistDue) {
                    Text("Пора замерить (прошло ${state.daysSinceWaist} дн.)", color = ChairWarning)
                } else {
                    Text(
                        state.latestWaistCm?.let { "Последний: $it см" }
                            ?: "Ещё не записывали",
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                OutlinedTextField(
                    value = waistInput,
                    onValueChange = { waistInput = it },
                    label = { Text("см") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                Button(
                    onClick = {
                        waistInput.replace(',', '.').toFloatOrNull()?.let(viewModel::logWaist)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = ChairAccent),
                ) {
                    Text("Сохранить талию")
                }
            }
        }
        Spacer(Modifier.height(8.dp))
    }
}
