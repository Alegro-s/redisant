import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants.dart';

class AppThemes {
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: AppConstants.blockBlack,
      onPrimary: AppConstants.surfaceWhite,
      secondary: AppConstants.terracotta,
      onSecondary: AppConstants.surfaceWhite,
      surface: AppConstants.surfaceWhite,
      onSurface: AppConstants.blockBlack,
      error: const Color(0xFFB00020),
      outline: const Color(0xFFE0E0DE),
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
        titleTextStyle: GoogleFonts.manrope(
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
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE8E8E6), thickness: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppConstants.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          side: const BorderSide(color: Color(0xFFE8E8E6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppConstants.blockBlack,
          foregroundColor: AppConstants.surfaceWhite,
          minimumSize: Size(double.infinity, AppConstants.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.blockBlack,
          foregroundColor: AppConstants.onBlock,
          minimumSize: Size(double.infinity, AppConstants.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppConstants.blockBlack,
          side: const BorderSide(color: AppConstants.blockBlack, width: 1.5),
          minimumSize: Size(double.infinity, AppConstants.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppConstants.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppConstants.terracottaDark, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
        bodyColor: AppConstants.blockBlack,
        displayColor: AppConstants.blockBlack,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppConstants.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: AppConstants.sheetHandle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.sheetTopRadius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppConstants.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        titleTextStyle: GoogleFonts.manrope(
          color: AppConstants.blockBlack,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: GoogleFonts.manrope(
          color: AppConstants.secondaryColor,
          fontSize: 15,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppConstants.blockBlack,
        contentTextStyle: GoogleFonts.manrope(
          color: AppConstants.onBlock,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppConstants.terracottaDark,
        textColor: AppConstants.blockBlack,
      ),
    );
  }
}
