import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'nexus_shell_theme.dart';

class NexusTheme {
  NexusTheme._();

  static TextStyle standaloneTextStyle(
    TextStyle base, {
    double fallbackFontSize = 14,
  }) {
    return base.copyWith(
      inherit: false,
      fontSize: base.fontSize ?? fallbackFontSize,
      textBaseline: base.textBaseline ?? TextBaseline.alphabetic,
    );
  }

  static TextTheme _stableTextTheme(TextTheme t) {
    TextStyle fix(TextStyle? s) {
      if (s == null) {
        return const TextStyle(
          inherit: false,
          height: 1.0,
          fontSize: 14,
          textBaseline: TextBaseline.alphabetic,
        );
      }
      return s.copyWith(
        inherit: false,
        fontSize: s.fontSize ?? 14,
        textBaseline: s.textBaseline ?? TextBaseline.alphabetic,
      );
    }

    return TextTheme(
      displayLarge: fix(t.displayLarge),
      displayMedium: fix(t.displayMedium),
      displaySmall: fix(t.displaySmall),
      headlineLarge: fix(t.headlineLarge),
      headlineMedium: fix(t.headlineMedium),
      headlineSmall: fix(t.headlineSmall),
      titleLarge: fix(t.titleLarge),
      titleMedium: fix(t.titleMedium),
      titleSmall: fix(t.titleSmall),
      bodyLarge: fix(t.bodyLarge),
      bodyMedium: fix(t.bodyMedium),
      bodySmall: fix(t.bodySmall),
      labelLarge: fix(t.labelLarge),
      labelMedium: fix(t.labelMedium),
      labelSmall: fix(t.labelSmall),
    );
  }

  static TextStyle _interLabel(double size, FontWeight w, [Color? color]) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: w,
        color: color,
      ).copyWith(inherit: false, textBaseline: TextBaseline.alphabetic);

  static InputDecorationTheme _inputDecorationTheme({
    required ColorScheme scheme,
    required Color fillColor,
    required Color borderEnabled,
    required Color borderFocused,
  }) {
    final hintColor = scheme.onSurfaceVariant.withValues(alpha: 0.58);
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderEnabled),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderFocused, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
      labelStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        inherit: false,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        textBaseline: TextBaseline.alphabetic,
      ),
      floatingLabelStyle: TextStyle(
        color: borderFocused,
        inherit: false,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        textBaseline: TextBaseline.alphabetic,
      ),
      hintStyle: TextStyle(
        color: hintColor,
        inherit: false,
        fontSize: 16,
        textBaseline: TextBaseline.alphabetic,
      ),
      helperStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        inherit: false,
        fontSize: 12,
        height: 1.35,
        textBaseline: TextBaseline.alphabetic,
      ),
      errorStyle: TextStyle(
        color: scheme.error,
        inherit: false,
        fontSize: 12,
        height: 1.35,
        textBaseline: TextBaseline.alphabetic,
      ),
      counterStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        inherit: false,
        fontSize: 12,
        textBaseline: TextBaseline.alphabetic,
      ),
    );
  }

  static const Color _accentDark = Color(0xFFC084FC);
  static const Color _lavenderSoft = Color(0xFFD8B4FE);
  static const Color _accentLight = Color(0xFF5C6BA3);

  static ThemeData darkPurple() {
    const scaffold = Color(0xFF0D1117);
    const surface = Color(0xFF161B22);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _accentDark,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF322454),
        onPrimaryContainer: Color(0xFFE9D5FF),
        secondary: _lavenderSoft,
        onSecondary: Color(0xFF0D1117),
        surface: surface,
        onSurface: Color(0xFFF0F6FC),
        surfaceContainerHighest: Color(0xFF242035),
        onSurfaceVariant: Color(0xFF8B949E),
        outline: Color(0xFF30363D),
        error: Color(0xFFFF7B72),
        onError: Color(0xFF0D1117),
        tertiary: Color(0xFF22C55E),
        onTertiary: Color(0xFF022C22),
        tertiaryContainer: Color(0xFF164E2A),
        onTertiaryContainer: Color(0xFFDCFCE7),
      ),
    );
    final textTheme = _stableTextTheme(
      GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFFD4D4D8),
        displayColor: const Color(0xFFFAFAFA),
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      textTheme: textTheme,
      primaryTextTheme: _stableTextTheme(base.primaryTextTheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: textTheme.titleLarge?.color,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textTheme.titleLarge?.color,
        ).copyWith(inherit: false),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF21262D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: _accentDark.withValues(alpha: 0.28)),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF21262D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: _accentDark.withValues(alpha: 0.42),
        labelTextStyle: WidgetStatePropertyAll(
          _interLabel(11, FontWeight.w500),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _accentDark, size: 24);
          }
          return IconThemeData(
            color:
                textTheme.bodyMedium?.color?.withValues(alpha: 0.65) ??
                base.colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: _accentDark,
        unselectedItemColor:
            textTheme.bodyMedium?.color?.withValues(alpha: 0.55) ??
            base.colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF3F3F46),
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor:
            textTheme.bodyMedium?.color?.withValues(alpha: 0.85) ??
            base.colorScheme.onSurfaceVariant,
        textColor: textTheme.bodyLarge?.color ?? base.colorScheme.onSurface,
        selectedColor: _accentDark,
        selectedTileColor: _accentDark.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      inputDecorationTheme: _inputDecorationTheme(
        scheme: base.colorScheme,
        fillColor: const Color(0xFF3C3C3C),
        borderEnabled: const Color(0xFF52525B),
        borderFocused: _accentDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: _interLabel(14, FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accentDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: _interLabel(14, FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _accentDark),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF3F3F46),
        contentTextStyle: standaloneTextStyle(
          GoogleFonts.inter(fontSize: 14, color: Colors.white),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _accentDark,
        unselectedLabelColor: textTheme.bodyMedium?.color?.withValues(
          alpha: 0.55,
        ),
        indicatorColor: _accentDark,
        dividerColor: const Color(0xFF3F3F46),
        labelStyle: _interLabel(13, FontWeight.w600),
        unselectedLabelStyle: _interLabel(13, FontWeight.w500),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF3C3C3C),
        selectedColor: _accentDark.withValues(alpha: 0.35),
        labelStyle: _interLabel(13, FontWeight.w400),
        side: const BorderSide(color: Color(0xFF52525B)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _accentDark,
      ),
      extensions: const [NexusShellTheme.dark],
    );
  }

  static ThemeData lightClean() {
    const scaffold = Color(0xFFF9FAFB);
    const surface = Color(0xFFFFFFFF);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: _accentLight,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE8EBF4),
        onPrimaryContainer: Color(0xFF2F364F),
        secondary: Color(0xFF6B7899),
        onSecondary: Colors.white,
        surface: surface,
        onSurface: Color(0xFF18181B),
        surfaceContainerHighest: Color(0xFFF4F4F5),
        onSurfaceVariant: Color(0xFF71717A),
        outline: Color(0xFFD4D4D8),
        error: Color(0xFFDC2626),
        onError: Colors.white,
        tertiary: Color(0xFF059669),
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFFFEF3C7),
        onTertiaryContainer: Color(0xFF78350F),
      ),
    );
    final textTheme = _stableTextTheme(
      GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFF3F3F46),
        displayColor: const Color(0xFF18181B),
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      textTheme: textTheme,
      primaryTextTheme: _stableTextTheme(base.primaryTextTheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: textTheme.titleLarge?.color,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textTheme.titleLarge?.color,
        ).copyWith(inherit: false),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE4E4E7)),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: _accentLight.withValues(alpha: 0.22),
        labelTextStyle: WidgetStatePropertyAll(
          _interLabel(11, FontWeight.w500),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _accentLight, size: 24);
          }
          return IconThemeData(
            color:
                textTheme.bodyMedium?.color?.withValues(alpha: 0.55) ??
                base.colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: _accentLight,
        unselectedItemColor:
            textTheme.bodyMedium?.color?.withValues(alpha: 0.5) ??
            base.colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE4E4E7),
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor:
            textTheme.bodyMedium?.color?.withValues(alpha: 0.8) ??
            base.colorScheme.onSurfaceVariant,
        textColor: textTheme.bodyLarge?.color ?? base.colorScheme.onSurface,
        selectedColor: _accentLight,
        selectedTileColor: _accentLight.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      inputDecorationTheme: _inputDecorationTheme(
        scheme: base.colorScheme,
        fillColor: const Color(0xFFF4F4F5),
        borderEnabled: const Color(0xFFD4D4D8),
        borderFocused: _accentLight,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: _interLabel(14, FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accentLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: _interLabel(14, FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _accentLight),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF27272A),
        contentTextStyle: standaloneTextStyle(
          GoogleFonts.inter(fontSize: 14, color: Colors.white),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _accentLight,
        unselectedLabelColor: textTheme.bodyMedium?.color?.withValues(
          alpha: 0.5,
        ),
        indicatorColor: _accentLight,
        dividerColor: const Color(0xFFE4E4E7),
        labelStyle: _interLabel(13, FontWeight.w600),
        unselectedLabelStyle: _interLabel(13, FontWeight.w500),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF4F4F5),
        selectedColor: _accentLight.withValues(alpha: 0.2),
        labelStyle: _interLabel(13, FontWeight.w400),
        side: const BorderSide(color: Color(0xFFD4D4D8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _accentLight,
      ),
      extensions: const [NexusShellTheme.light],
    );
  }

  static ThemeData darkSlate() {
    const accent = Color(0xFF3794FF);
    const surface = Color(0xFF252526);
    const scaffold = Color(0xFF1E1E1E);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF094771),
        onPrimaryContainer: Color(0xFFBAE6FD),
        secondary: Color(0xFF89D4FF),
        surface: surface,
        onSurface: Color(0xFFE4E4E7),
        surfaceContainerHighest: Color(0xFF323232),
        onSurfaceVariant: Color(0xFFA1A1AA),
        outline: Color(0xFF52525B),
        error: Color(0xFFF87171),
        onError: Color(0xFF450A0A),
      ),
    );
    final textTheme = _stableTextTheme(
      GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFFD4D4D8),
        displayColor: const Color(0xFFFAFAFA),
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      textTheme: textTheme,
      primaryTextTheme: _stableTextTheme(base.primaryTextTheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: textTheme.titleLarge?.color,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textTheme.titleLarge?.color,
        ).copyWith(inherit: false),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF2D2D30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF3F3F46)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.35),
        labelTextStyle: WidgetStatePropertyAll(
          _interLabel(11, FontWeight.w500),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accent, size: 24);
          }
          return IconThemeData(
            color:
                textTheme.bodyMedium?.color?.withValues(alpha: 0.65) ??
                base.colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor:
            textTheme.bodyMedium?.color?.withValues(alpha: 0.55) ??
            base.colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: _inputDecorationTheme(
        scheme: base.colorScheme,
        fillColor: const Color(0xFF3C3C3C),
        borderEnabled: const Color(0xFF52525B),
        borderFocused: accent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: textTheme.bodyMedium?.color?.withValues(
          alpha: 0.55,
        ),
        indicatorColor: accent,
        dividerColor: const Color(0xFF3F3F46),
        labelStyle: _interLabel(13, FontWeight.w600),
        unselectedLabelStyle: _interLabel(13, FontWeight.w500),
      ),
      extensions: [
        NexusShellTheme.dark.copyWith(
          messageBubbleMine: const Color(0xFF1E40AF),
          messageBubbleOther: const Color(0xFF2F3136),
        ),
      ],
    );
  }
}
