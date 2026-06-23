package com.chairup.android.ui.screens.health

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.chairup.android.integration.health.HealthAuthState
import com.chairup.android.ui.theme.ChairAccent
import com.chairup.android.ui.theme.ChairSurface

@Composable
fun HealthConnectScreen(
    viewModel: HealthViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current

    val authLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { viewModel.refresh() }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("HUAWEI Health", style = MaterialTheme.typography.headlineMedium)
        Text(
            state.statusMessage,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Card(
            colors = CardDefaults.cardColors(containerColor = ChairSurface),
            shape = RoundedCornerShape(20.dp),
        ) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Статус", style = MaterialTheme.typography.titleMedium)
                Text(authLabel(state.authState), color = ChairAccent)
                Text("HMS в сборке: ${if (state.hmsEnabled) "да" else "нет"}")
            }
        }

        Button(
            onClick = {
                val intent = viewModel.prepareAuthorizeIntent()
                if (intent != null) {
                    authLauncher.launch(intent)
                } else {
                    context.startActivity(
                        context.packageManager.getLaunchIntentForPackage("com.huawei.health")
                            ?: Intent(Intent.ACTION_VIEW, Uri.parse("https://consumer.huawei.com/en/mobileservices/health/")),
                    )
                }
            },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(20.dp),
            colors = ButtonDefaults.buttonColors(containerColor = ChairAccent),
        ) {
            Text(if (state.hmsEnabled) "Подключить HUAWEI Health (OAuth)" else "Открыть HUAWEI Health")
        }

        OutlinedButton(
            onClick = {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                }
                context.startActivity(intent)
            },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(20.dp),
        ) {
            Text("Исключение из энергосбережения EMUI")
        }

        OutlinedButton(
            onClick = {
                context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", context.packageName, null)
                })
            },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(20.dp),
        ) {
            Text("Автозапуск / уведомления (настройки приложения)")
        }
    }
}

private fun authLabel(state: HealthAuthState): String = when (state) {
    HealthAuthState.Unknown -> "Проверка…"
    HealthAuthState.NotConfigured -> "Нет agconnect-services.json"
    HealthAuthState.NotAuthorized -> "Нужна авторизация"
    is HealthAuthState.Authorized -> "Подключено ✓"
    is HealthAuthState.Error -> "Ошибка: ${state.message}"
}
