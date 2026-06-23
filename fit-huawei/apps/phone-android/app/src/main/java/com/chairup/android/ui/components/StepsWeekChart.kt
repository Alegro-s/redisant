package com.chairup.android.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.chairup.android.ui.theme.ChairAccent
import com.chairup.android.ui.theme.ChairOnBackgroundMuted
import java.time.LocalDate
import java.time.format.DateTimeFormatter

@Composable
fun StepsWeekChart(
    days: List<Pair<String, Int>>,
    modifier: Modifier = Modifier,
) {
    val data = if (days.size >= 7) days.takeLast(7) else {
        val fmt = DateTimeFormatter.ISO_LOCAL_DATE
        val today = LocalDate.now()
        (6 downTo 0).map { i ->
            val d = today.minusDays(i.toLong()).format(fmt)
            d to (days.find { it.first == d }?.second ?: 0)
        }
    }
    val max = (data.maxOfOrNull { it.second } ?: 1).coerceAtLeast(1)

    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Bottom,
        ) {
            data.forEach { (date, steps) ->
                val ratio = steps.toFloat() / max.toFloat()
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Bottom,
                    modifier = Modifier.weight(1f),
                ) {
                    Surface(
                        modifier = Modifier.height((ratio * 100).dp.coerceAtLeast(4.dp)),
                        shape = RoundedCornerShape(topStart = 6.dp, topEnd = 6.dp),
                        color = ChairAccent,
                    ) {}
                    Text(
                        dayLabel(date),
                        style = MaterialTheme.typography.labelLarge,
                        color = ChairOnBackgroundMuted,
                    )
                }
            }
        }
        Text(
            "макс ${max} шагов",
            style = MaterialTheme.typography.labelLarge,
            color = ChairOnBackgroundMuted,
        )
    }
}

private fun dayLabel(isoDate: String): String {
    return try {
        val d = LocalDate.parse(isoDate)
        when (d.dayOfWeek.value) {
            1 -> "Пн"
            2 -> "Вт"
            3 -> "Ср"
            4 -> "Чт"
            5 -> "Пт"
            6 -> "Сб"
            else -> "Вс"
        }
    } catch (_: Exception) {
        isoDate.takeLast(2)
    }
}
