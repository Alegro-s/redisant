package com.chairup.android.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

private val ChairColorScheme = darkColorScheme(
    primary = ChairAccent,
    onPrimary = ChairBackground,
    primaryContainer = ChairAccentDim,
    secondary = ChairWarning,
    background = ChairBackground,
    onBackground = ChairOnBackground,
    surface = ChairSurface,
    onSurface = ChairOnBackground,
    surfaceVariant = ChairSurfaceVariant,
    onSurfaceVariant = ChairOnBackgroundMuted,
    outline = ChairOnBackgroundMuted,
)

@Composable
fun ChairUpTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = ChairColorScheme,
        typography = ChairTypography,
        content = content,
    )
}
