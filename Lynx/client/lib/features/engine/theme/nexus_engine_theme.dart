import 'package:flutter/material.dart';

abstract final class NexusEngineTheme {
  static const Color workspaceBg = Color(0xFF1E1E1E);
  static const Color panel = Color(0xFF252526);
  static const Color panelElevated = Color(0xFF2D2D30);
  static const Color border = Color(0xFF3F3F46);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color accentDim = Color(0xFF6D28D9);
  static const Color onWorkspace = Color(0xFFE4E4E7);

  static ThemeData layerOver(BuildContext context) {
    final base = Theme.of(context);
    final cs = ColorScheme.dark(
      surface: workspaceBg,
      surfaceContainerHighest: panel,
      surfaceContainerHigh: panelElevated,
      primary: accent,
      onPrimary: Colors.white,
      secondary: accentDim,
      onSurface: onWorkspace,
      outline: border,
    );
    return base.copyWith(
      colorScheme: cs,
      scaffoldBackgroundColor: workspaceBg,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: panel,
        foregroundColor: onWorkspace,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: panel,
        indicatorColor: accent.withValues(alpha: 0.35),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      popupMenuTheme: PopupMenuThemeData(
        color: panelElevated,
        surfaceTintColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: panelElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        textStyle: const TextStyle(color: onWorkspace, fontSize: 12),
      ),
    );
  }
}
