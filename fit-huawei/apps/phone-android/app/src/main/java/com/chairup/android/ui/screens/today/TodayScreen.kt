package com.chairup.android.ui.screens.today

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
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.chairup.android.ui.components.StepsWeekChart
import com.chairup.android.ui.theme.ChairAccent
import com.chairup.android.ui.theme.ChairSurface

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun TodayScreen(
    onOpenHealth: () -> Unit,
    onOpenStrength: () -> Unit,
    onOpenWeeklyReport: () -> Unit = {},
    onStartMicro: (slotIndex: Int) -> Unit,
    viewModel: TodayViewModel = hiltViewModel(),
) {
    val screen by viewModel.state.collectAsStateWithLifecycle()
    val refreshing by viewModel.isRefreshing.collectAsStateWithLifecycle()
    val metrics = screen.metrics
    val micro = screen.micro

    PullToRefreshBox(
        isRefreshing = refreshing,
        onRefresh = { viewModel.refresh() },
        modifier = Modifier.fillMaxSize(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column {
                    Text("ChairUp", style = MaterialTheme.typography.headlineMedium)
                    Text(
                        "Wave 6 · неделя ${micro.waveWeek} · цель ${micro.stepGoal} шагов",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Text(
                    "${screen.today.dailyScore.toInt()}",
                    style = MaterialTheme.typography.displayLarge,
                    color = ChairAccent,
                    fontWeight = FontWeight.Bold,
                )
            }

            if (screen.syncStatus.isNotBlank()) {
                Text(
                    screen.syncStatus,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Card(
                colors = CardDefaults.cardColors(containerColor = ChairSurface),
                shape = RoundedCornerShape(20.dp),
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("Режим «Кресло»", style = MaterialTheme.typography.titleMedium)
                        Text(
                            if (micro.chairMode) "Напоминания включены" else "Только ручной старт",
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        micro.nextSlot?.let {
                            Text(
                                "След. слот ~${it.label} (через ${micro.nextSlotInMin} мин)",
                                style = MaterialTheme.typography.labelLarge,
                                modifier = Modifier.padding(top = 4.dp),
                            )
                        }
                    }
                    Switch(
                        checked = micro.chairMode,
                        onCheckedChange = viewModel::setChairMode,
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                StatCard("${micro.microDone}/${micro.microTarget}", "микро", Modifier.weight(1f))
                StatCard("${metrics.todaySteps}", "шаги", Modifier.weight(1f))
                StatCard(
                    "${screen.today.proteinG.toInt()}/${screen.today.proteinTargetG.toInt()}",
                    "белок",
                    Modifier.weight(1f),
                )
                StatCard(metrics.sleepLabel, "сон", Modifier.weight(1f))
            }

            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                micro.slots.forEach { slot ->
                    val done = slot.index in micro.completedSlotIndices
                    FilterChip(
                        selected = done,
                        onClick = {
                            if (!done) onStartMicro(slot.index)
                        },
                        label = { Text(slot.label) },
                        enabled = !done,
                    )
                }
            }

            Button(
                onClick = {
                    val idx = micro.nextSlot?.index
                        ?: micro.slots.firstOrNull { it.index !in micro.completedSlotIndices }?.index
                        ?: 0
                    onStartMicro(idx)
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                shape = RoundedCornerShape(20.dp),
                colors = ButtonDefaults.buttonColors(containerColor = ChairAccent),
            ) {
                Text("▶ 2 минуты сейчас")
            }

            Card(
                colors = CardDefaults.cardColors(containerColor = ChairSurface),
                shape = RoundedCornerShape(20.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("Шаги за 7 дней", style = MaterialTheme.typography.titleMedium)
                    StepsWeekChart(metrics.stepsLast7Days)
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = onOpenStrength, modifier = Modifier.weight(1f)) {
                    Text(
                        if (screen.strength.streakOk) "Сила ✓" else "Сила ${screen.strength.sessionsThisWeek}/${screen.strength.weeklyGoal}",
                    )
                }
                OutlinedButton(onClick = onOpenWeeklyReport, modifier = Modifier.weight(1f)) {
                    Text("Отчёт")
                }
                AssistChip(
                    onClick = onOpenHealth,
                    label = { Text("Health") },
                    colors = AssistChipDefaults.assistChipColors(labelColor = ChairAccent),
                )
            }
        }
    }
}

@Composable
private fun StatCard(value: String, label: String, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = ChairSurface),
        shape = RoundedCornerShape(16.dp),
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(value, style = MaterialTheme.typography.headlineMedium, color = ChairAccent, maxLines = 1)
            Text(label, style = MaterialTheme.typography.labelLarge)
        }
    }
}
