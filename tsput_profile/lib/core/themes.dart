import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants.dart';

class AppThemes {
  static TextStyle _exo({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.exo2(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: AppConstants.blockBlack,
      onPrimary: AppConstants.surfaceWhite,
      secondary: AppConstants.terracotta,
      onSecondary: AppConstants.surfaceWhite,
      surface: AppConstants.surfaceWhite,
      onSurface: AppConstants.blockBlack,
      error: const Color(0xFFB00020),
      outline: AppConstants.borderSubtle,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppConstants.blockBlack,
      scaffoldBackgroundColor: AppConstants.surfaceWhite,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: AppConstants.surfaceWhite,
        foregroundColor: AppConstants.blockBlack,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: _exo(
          color: AppConstants.blockBlack,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppConstants.surfaceWhite,
        selectedItemColor: AppConstants.terracotta,
        unselectedItemColor: AppConstants.secondaryColor,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: _exo(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: _exo(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      dividerTheme: const DividerThemeData(color: AppConstants.borderSubtle, thickness: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppConstants.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          side: const BorderSide(color: AppConstants.borderSubtle),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppConstants.blockBlack,
          foregroundColor: AppConstants.surfaceWhite,
          minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: _exo(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppConstants.blockBlack,
          side: const BorderSide(color: AppConstants.blockBlack, width: 1.5),
          minimumSize: const Size(double.infinity, AppConstants.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: _exo(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppConstants.surfaceWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppConstants.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppConstants.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppConstants.blockBlack, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.exo2TextTheme(base.textTheme).apply(
        bodyColor: AppConstants.blockBlack,
        displayColor: AppConstants.blockBlack,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppConstants.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AppConstants.sheetHandle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sheetTopRadius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppConstants.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: _exo(color: AppConstants.blockBlack, fontSize: 18, fontWeight: FontWeight.w800),
        contentTextStyle: _exo(color: AppConstants.secondaryColor, fontSize: 15, height: 1.45),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppConstants.blockBlack,
        textColor: AppConstants.blockBlack,
      ),
    );
  }
}
