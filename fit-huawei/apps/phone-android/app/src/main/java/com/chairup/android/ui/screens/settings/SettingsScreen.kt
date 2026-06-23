package com.chairup.android.ui.screens.settings

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.chairup.android.BuildConfig
import com.chairup.android.ui.theme.ChairSurface

@Composable
fun SettingsScreen(
    onOpenPrivacy: () -> Unit = {},
    onOpenWeeklyReport: () -> Unit = {},
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val dnd by viewModel.dndEnabled.collectAsStateWithLifecycle()
    val nudgeCount by viewModel.nudgeCountToday.collectAsStateWithLifecycle()
    val exportMsg by viewModel.exportMessage.collectAsStateWithLifecycle()
    var pendingJson by remember { mutableStateOf<String?>(null) }

    val saveLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.CreateDocument("application/json"),
    ) { uri: Uri? ->
        val json = pendingJson
        if (uri != null && json != null) viewModel.writeBackup(uri, json)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(16.dp),
    ) {
        Text("Настройки", style = MaterialTheme.typography.headlineMedium)
        Text(
            "Версия ${BuildConfig.VERSION_NAME} · HMS: ${if (BuildConfig.HMS_ENABLED) "да" else "нет"}",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Card(
            colors = CardDefaults.cardColors(containerColor = ChairSurface),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("Не беси (22:00–08:00)", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "Пушей сегодня: $nudgeCount / 6",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Switch(checked = dnd, onCheckedChange = viewModel::setDnd)
            }
        }

        OutlinedButton(onClick = onOpenWeeklyReport, modifier = Modifier.fillMaxWidth()) {
            Text("Недельный отчёт")
        }

        Button(
            onClick = {
                viewModel.exportBackup { json ->
                    pendingJson = json
                    saveLauncher.launch("chairup-backup-${System.currentTimeMillis()}.json")
                }
            },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Экспорт JSON в Files")
        }

        OutlinedButton(onClick = onOpenPrivacy, modifier = Modifier.fillMaxWidth()) {
            Text("Политика конфиденциальности")
        }

        if (exportMsg.isNotBlank()) {
            Text(exportMsg, style = MaterialTheme.typography.bodyLarge)
        }

        Text(
            "Виджет 2×2: долгое нажатие на рабочий стол → виджеты → ChairUp.\n" +
                "Часы: DevEco → watch-harmony → Form «8 точек».",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
