package com.chairup.android.ui.screens.coach

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.chairup.android.ui.theme.ChairAccent
import com.chairup.android.ui.theme.ChairSurface

@Composable
fun WeeklyReportScreen(
    viewModel: WeeklyReportViewModel = hiltViewModel(),
) {
    val report by viewModel.report.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("Недельный отчёт", style = MaterialTheme.typography.headlineMedium)
        Text(
            report.summary,
            style = MaterialTheme.typography.titleMedium,
            color = ChairAccent,
        )

        ReportCard("Daily Score", "${report.avgScore.toInt()} в среднем")
        ReportCard("Микро-сессии", "${report.microTotal} за 7 дней")
        ReportCard("Белок", "${(report.avgProteinRatio * 100).toInt()}% от цели")
        ReportCard("Успешные дни", "${report.successfulDays}/7 (score ≥ 70)")
        ReportCard(
            "Тренд веса (MA7)",
            "${if (report.weightTrendKg <= 0) "" else "+"}${"%.1f".format(report.weightTrendKg)} кг",
        )

        if (!report.hasEnoughData) {
            Text(
                "Нужно минимум 2 дня данных для полного отчёта.",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun ReportCard(title: String, value: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = ChairSurface),
        shape = RoundedCornerShape(16.dp),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = MaterialTheme.typography.labelLarge)
            Text(value, style = MaterialTheme.typography.headlineSmall, color = ChairAccent)
        }
    }
}
