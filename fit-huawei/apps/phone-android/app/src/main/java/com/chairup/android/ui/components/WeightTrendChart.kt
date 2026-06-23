package com.chairup.android.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.chairup.android.domain.WeightPoint
import com.chairup.android.ui.theme.ChairAccent
import com.chairup.android.ui.theme.ChairOnBackgroundMuted

@Composable
fun WeightTrendChart(
    points: List<WeightPoint>,
    modifier: Modifier = Modifier,
) {
    if (points.isEmpty()) {
        Text("Добавьте вес — появится график MA7", color = ChairOnBackgroundMuted)
        return
    }
    val minY = points.minOf { it.ma7 ?: it.kg } - 1f
    val maxY = points.maxOf { it.ma7 ?: it.kg } + 1f
    val range = (maxY - minY).coerceAtLeast(1f)

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(140.dp),
    ) {
        val w = size.width
        val h = size.height
        val stepX = if (points.size > 1) w / (points.size - 1) else w

        fun yFor(kg: Float) = h - ((kg - minY) / range) * h

        val rawPath = Path()
        points.forEachIndexed { i, p ->
            val x = i * stepX
            val y = yFor(p.kg)
            if (i == 0) rawPath.moveTo(x, y) else rawPath.lineTo(x, y)
        }
        drawPath(
            rawPath,
            color = ChairOnBackgroundMuted.copy(alpha = 0.5f),
            style = Stroke(width = 3f, cap = StrokeCap.Round),
        )

        val maPath = Path()
        var started = false
        points.forEachIndexed { i, p ->
            val ma = p.ma7 ?: return@forEachIndexed
            val x = i * stepX
            val y = yFor(ma)
            if (!started) {
                maPath.moveTo(x, y)
                started = true
            } else {
                maPath.lineTo(x, y)
            }
        }
        if (started) {
            drawPath(
                maPath,
                color = ChairAccent,
                style = Stroke(width = 4f, cap = StrokeCap.Round),
            )
        }
        points.forEachIndexed { i, p ->
            drawCircle(
                color = ChairAccent,
                radius = 5f,
                center = Offset(i * stepX, yFor(p.kg)),
            )
        }
    }
    Text(
        "Линия: MA7 · точки: взвешивание",
        style = MaterialTheme.typography.labelLarge,
        color = ChairOnBackgroundMuted,
    )
}
