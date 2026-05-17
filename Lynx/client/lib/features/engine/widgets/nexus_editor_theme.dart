import 'package:flutter/material.dart';

class NexusEditorTheme {
  NexusEditorTheme._();

  static const Color workspaceBg = Color(0xFF16101F);
  static const Color panelBg = Color(0xFF1E1830);
  static const Color panelBorder = Color(0xFF3D3458);
  static const Color accent = Color(0xFF7C6CF0);
  static const Color accentDim = Color(0xFF5B4FCF);

  static Widget scope(BuildContext context, {required Widget child}) {
    final base = Theme.of(context);
    final cs = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: workspaceBg,
      surfaceContainerHighest: panelBg,
      primary: accent,
      secondary: accentDim,
      onPrimary: Colors.white,
      onSurface: const Color(0xFFE8E4F5),
      outline: panelBorder,
    );
    return Theme(
      data: base.copyWith(
        colorScheme: cs,
        scaffoldBackgroundColor: workspaceBg,
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF221B33),
          foregroundColor: cs.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF221B33),
          indicatorColor: accent.withValues(alpha: 0.22),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        tabBarTheme: TabBarThemeData(
          dividerColor: panelBorder.withValues(alpha: 0.5),
          labelColor: accent,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: accent,
        ),
        dividerTheme: DividerThemeData(color: panelBorder.withValues(alpha: 0.6)),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF2E2640),
          contentTextStyle: TextStyle(color: cs.onSurface),
        ),
      ),
      child: child,
    );
  }

  static BoxDecoration panelDecoration(ColorScheme cs, {bool leftBorder = false, bool rightBorder = false, bool topBorder = false, bool bottomBorder = false}) {
    return BoxDecoration(
      color: cs.surfaceContainerHighest,
      border: Border(
        left: leftBorder ? BorderSide(color: cs.outline.withValues(alpha: 0.55)) : BorderSide.none,
        right: rightBorder ? BorderSide(color: cs.outline.withValues(alpha: 0.55)) : BorderSide.none,
        top: topBorder ? BorderSide(color: cs.outline.withValues(alpha: 0.55)) : BorderSide.none,
        bottom: bottomBorder ? BorderSide(color: cs.outline.withValues(alpha: 0.55)) : BorderSide.none,
      ),
    );
  }
}
