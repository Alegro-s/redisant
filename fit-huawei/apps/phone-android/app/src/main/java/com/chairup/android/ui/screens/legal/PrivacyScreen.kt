package com.chairup.android.ui.screens.legal

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun PrivacyScreen() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(12.dp),
    ) {
        Text("Политика конфиденциальности", style = MaterialTheme.typography.headlineMedium)
        Text(PRIVACY_TEXT, style = MaterialTheme.typography.bodyLarge)
    }
}

private val PRIVACY_TEXT = """
ChairUp хранит данные о тренировках, весе, белке и микро-сессиях локально на вашем устройстве.

HUAWEI Health: при вашем согласии приложение читает шаги, сон, пульс и тренировки через HMS Health Kit. Данные не передаются на сторонние серверы ChairUp.

Wear Engine: синхронизация с часами HarmonyOS происходит напрямую между телефоном и часами.

Резервная копия JSON экспортируется только по вашему запросу в выбранную вами папку.

Вы можете удалить все данные, удалив приложение или очистив его данные в настройках Android.

ChairUp не является медицинским ПО. Перед изменением диеты или нагрузки проконсультируйтесь с врачом.
""".trimIndent()
