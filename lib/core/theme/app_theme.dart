import 'package:avogs/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        primary: AppColors.primaryDark,
        secondary: AppColors.accentLime,
        surface: AppColors.backgroundCream,
        error: AppColors.errorRed,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.backgroundCream,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.accentLime.withValues(alpha: 0.35),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.primaryDark,
        selectedIconTheme: const IconThemeData(color: AppColors.accentLime),
        unselectedIconTheme: IconThemeData(
          color: AppColors.white.withValues(alpha: 0.7),
        ),
        selectedLabelTextStyle: GoogleFonts.dmSans(
          color: AppColors.accentLime,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: GoogleFonts.dmSans(
          color: AppColors.white.withValues(alpha: 0.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData dark() {
    const surface = Color(0xFF122419);
    const surfaceContainer = Color(0xFF162B1E);
    const inputFill = Color(0xFF1A2F22);

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accentLime,
        primary: AppColors.accentLime,
        onPrimary: AppColors.primaryDark,
        secondary: AppColors.primaryGreen,
        onSurface: AppColors.white,
        onSurfaceVariant: AppColors.mutedGray,
        surface: surface,
        error: AppColors.errorRed,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0E1A13),
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.accentLime.withValues(alpha: 0.25),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.primaryDark,
        selectedIconTheme: const IconThemeData(color: AppColors.accentLime),
        unselectedIconTheme: IconThemeData(
          color: AppColors.white.withValues(alpha: 0.7),
        ),
        selectedLabelTextStyle: GoogleFonts.dmSans(
          color: AppColors.accentLime,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: GoogleFonts.dmSans(
          color: AppColors.white.withValues(alpha: 0.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.white,
          side: BorderSide(color: AppColors.white.withValues(alpha: 0.24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        labelStyle: GoogleFonts.dmSans(color: AppColors.mutedGray),
        hintStyle: GoogleFonts.dmSans(color: AppColors.mutedGray),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentLime, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryDark;
            }
            return AppColors.white;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.accentLime;
            }
            return inputFill;
          }),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.white.withValues(alpha: 0.12),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return GoogleFonts.dmSansTextTheme(base).copyWith(
      headlineLarge: GoogleFonts.dmSans(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
      labelLarge: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
      bodyMedium: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
    );
  }

  static TextStyle mono({double size = 14, Color? color}) {
    return GoogleFonts.dmMono(fontSize: size, color: color);
  }
}
