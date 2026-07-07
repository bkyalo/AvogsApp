import 'package:avogs/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  static final ThemeData lightTheme = light();
  static final ThemeData darkTheme = dark();

  static TextStyle _sans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static final TextStyle _filledButtonText =
      _sans(fontWeight: FontWeight.w700, fontSize: 15);

  static ThemeData light() {
    const onSurface = AppColors.primaryDark;
    const onSurfaceVariant = Color(0xFF5E5E54);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      primary: AppColors.primaryDark,
      onPrimary: AppColors.white,
      secondary: AppColors.accentLime,
      onSecondary: AppColors.primaryDark,
      surface: AppColors.backgroundCream,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      error: AppColors.errorRed,
      brightness: Brightness.light,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundCream,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        titleTextStyle: _sans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.accentLime.withValues(alpha: 0.35),
        labelTextStyle: WidgetStatePropertyAll(
          _sans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.primaryDark,
        selectedIconTheme: const IconThemeData(color: AppColors.accentLime),
        unselectedIconTheme: IconThemeData(
          color: AppColors.white.withValues(alpha: 0.7),
        ),
        selectedLabelTextStyle: _sans(
          color: AppColors.accentLime,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: _sans(
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
          textStyle: _filledButtonText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        labelStyle: _sans(color: onSurfaceVariant),
        hintStyle: _sans(color: onSurfaceVariant),
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
      listTileTheme: ListTileThemeData(
        textColor: onSurface,
        iconColor: onSurfaceVariant,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: _sans(color: onSurface),
      ),
    );
  }

  static ThemeData dark() {
    const surface = Color(0xFF122419);
    const surfaceContainer = Color(0xFF162B1E);
    const inputFill = Color(0xFF1A2F22);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accentLime,
      primary: AppColors.accentLime,
      onPrimary: AppColors.primaryDark,
      secondary: AppColors.primaryGreen,
      onSurface: AppColors.white,
      onSurfaceVariant: AppColors.mutedGray,
      surface: surface,
      error: AppColors.errorRed,
      brightness: Brightness.dark,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0E1A13),
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        titleTextStyle: _sans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.accentLime.withValues(alpha: 0.25),
        labelTextStyle: WidgetStatePropertyAll(
          _sans(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.primaryDark,
        selectedIconTheme: const IconThemeData(color: AppColors.accentLime),
        unselectedIconTheme: IconThemeData(
          color: AppColors.white.withValues(alpha: 0.7),
        ),
        selectedLabelTextStyle: _sans(
          color: AppColors.accentLime,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: _sans(
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
          textStyle: _filledButtonText,
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
        labelStyle: _sans(color: AppColors.mutedGray),
        hintStyle: _sans(color: AppColors.mutedGray),
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

  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    final themed = GoogleFonts.dmSansTextTheme(base).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return themed.copyWith(
      headlineLarge: _sans(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
      titleLarge: _sans(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      titleMedium: _sans(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      labelLarge: _sans(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyMedium: _sans(
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      bodySmall: _sans(
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  static TextStyle get filledButtonTextStyle => _filledButtonText;

  static TextStyle mono({double size = 14, Color? color}) {
    return GoogleFonts.dmMono(fontSize: size, color: color);
  }

  static TextStyle monoFrom(BuildContext context, {double size = 14}) {
    return GoogleFonts.dmMono(
      fontSize: size,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }
}
