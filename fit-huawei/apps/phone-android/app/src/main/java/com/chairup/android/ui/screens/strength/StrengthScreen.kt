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
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.chairup.android.domain.strength.StrengthTemplateId
import com.chairup.android.ui.theme.ChairAccent
import com.chairup.android.ui.theme.ChairSurface
import com.chairup.android.ui.theme.ChairSuccess

@Composable
fun StrengthScreen(
    onStartTemplate: (StrengthTemplateId) -> Unit,
    viewModel: StrengthViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("Силовая", style = MaterialTheme.typography.headlineMedium)
        Text(
            "Wave 4 · 2× в неделю · +1 повт/нед",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Card(colors = CardDefaults.cardColors(containerColor = ChairSurface), shape = RoundedCornerShape(20.dp)) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("На этой неделе", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "${state.sessionsThisWeek}/${state.weeklyGoal}",
                        color = if (state.streakOk) ChairSuccess else ChairAccent,
                        fontWeight = FontWeight.Bold,
                    )
                }
                LinearProgressIndicator(
                    progress = {
                        (state.sessionsThisWeek.toFloat() / state.weeklyGoal).coerceIn(0f, 1f)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    color = ChairAccent,
                )
                if (state.todayDone) {
                    Text("Сегодня уже тренировались ✓", color = ChairSuccess)
                }
                state.lastWorkoutLabel?.let {
                    Text("Последняя: $it", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }

        state.templates.forEach { card ->
            TemplateCard(
                title = card.template.title,
                subtitle = card.template.subtitle,
                minutes = card.template.minutesLabel,
                exercises = card.template.exercises.joinToString(" · ") { ex ->
                    val reps = card.targetRepsByExercise[ex.id] ?: ex.baseReps
                    val unit = if (ex.id == "plank") "${reps}с" else "×$reps"
                    "${ex.name} $unit"
                },
                onStart = { onStartTemplate(card.template.id) },
            )
        }

        Text(
            "Отдых 60 с между подходами — на часах таймер. Импорт из HUAWEI Health — скоро.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun TemplateCard(
    title: String,
    subtitle: String,
    minutes: String,
    exercises: String,
    onStart: () -> Unit,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = ChairSurface),
        shape = RoundedCornerShape(20.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(title, style = MaterialTheme.typography.titleLarge)
                Text(minutes, color = ChairAccent)
            }
            Text(subtitle, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(exercises, style = MaterialTheme.typography.bodyLarge)
            Button(
                onClick = onStart,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = ChairAccent),
            ) {
                Text("Начать")
            }
        }
    }
}
