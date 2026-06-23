package com.chairup.android.ui.screens.micro

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.chairup.android.ui.theme.ChairAccent
import kotlinx.coroutines.delay

@Composable
fun MicroTimerScreen(
    slotIndex: Int,
    onDone: () -> Unit,
    onCancel: () -> Unit,
    viewModel: MicroTimerViewModel = hiltViewModel(),
) {
    val totalSec = 120
    var secondsLeft by remember { mutableIntStateOf(totalSec) }
    var saving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        while (secondsLeft > 0) {
            delay(1000)
            secondsLeft -= 1
        }
    }

    val progress = 1f - secondsLeft.toFloat() / totalSec.toFloat()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text("2 минуты", style = MaterialTheme.typography.headlineMedium)
        Text(
            "пройдись · вода · приседания",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(24.dp))
        Text(
            text = formatTime(secondsLeft),
            style = MaterialTheme.typography.displayLarge,
            color = ChairAccent,
            fontWeight = FontWeight.Bold,
        )
        Spacer(Modifier.height(16.dp))
        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier.fillMaxWidth(),
            color = ChairAccent,
        )
        Spacer(Modifier.height(32.dp))
        Button(
            onClick = {
                if (saving) return@Button
                saving = true
                val elapsed = totalSec - secondsLeft
                viewModel.complete(slotIndex, elapsed.coerceAtLeast(60)) { result ->
                    saving = false
                    result.onSuccess { onDone() }
                        .onFailure { error = it.message }
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(56.dp),
            shape = RoundedCornerShape(20.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ChairAccent),
        ) {
            Text(if (saving) "Сохраняю…" else "Готово")
        }
        Button(onClick = onCancel, modifier = Modifier.fillMaxWidth()) {
            Text("Отмена")
        }
        error?.let {
            Text(it, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(top = 8.dp))
        }
    }
}

private fun formatTime(totalSec: Int): String {
    val m = totalSec / 60
    val s = totalSec % 60
    val sec = if (s < 10) "0$s" else "$s"
    return "$m:$sec"
}
