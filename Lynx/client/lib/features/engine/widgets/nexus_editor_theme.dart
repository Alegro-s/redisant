import 'package:flutter/material.dart';

/// Unity-inspired editor chrome: тёмно-серая · серая · белая.
class NexusEditorTheme {
  NexusEditorTheme._();

  static const Color workspaceBg = Color(0xFF1E1E1E);
  static const Color panelBg = Color(0xFF383838);
  static const Color panelBorder = Color(0xFF4A4A4A);
  static const Color accent = Color(0xFFE4E4E7);
  static const Color accentDim = Color(0xFFA1A1AA);
  static const Color toolbarBg = Color(0xFF2D2D30);

  static Widget scope(BuildContext context, {required Widget child}) {
    final base = Theme.of(context);
    final cs = ColorScheme.dark(
      primary: accent,
      onPrimary: const Color(0xFF18181B),
      secondary: accentDim,
      surface: workspaceBg,
      onSurface: const Color(0xFFF4F4F5),
      surfaceContainerHighest: panelBg,
      surfaceContainerHigh: const Color(0xFF2D2D30),
      onSurfaceVariant: const Color(0xFFA1A1AA),
      outline: panelBorder,
      error: const Color(0xFFF87171),
    );
    return Theme(
      data: base.copyWith(
        colorScheme: cs,
        scaffoldBackgroundColor: workspaceBg,
        iconTheme: const IconThemeData(size: 20),
        appBarTheme: AppBarTheme(
          backgroundColor: toolbarBg,
          foregroundColor: cs.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 44,
          titleSpacing: 12,
          actionsPadding: const EdgeInsets.only(right: 8),
          titleTextStyle: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: toolbarBg,
          indicatorColor: accent.withValues(alpha: 0.18),
          height: 56,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        tabBarTheme: TabBarThemeData(
          dividerColor: panelBorder.withValues(alpha: 0.5),
          labelColor: cs.onSurface,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: accent,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        dividerTheme: DividerThemeData(color: panelBorder.withValues(alpha: 0.65)),
        listTileTheme: const ListTileThemeData(
          dense: true,
          minVerticalPadding: 6,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF2D2D30),
          contentTextStyle: TextStyle(color: cs.onSurface),
        ),
      ),
      child: child,
    );
  }

  static BoxDecoration panelDecoration(
    ColorScheme cs, {
    bool leftBorder = false,
    bool rightBorder = false,
    bool topBorder = false,
    bool bottomBorder = false,
  }) {
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
