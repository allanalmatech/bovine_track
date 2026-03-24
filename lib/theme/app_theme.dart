import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF00450D);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF065F18);
  static const Color onPrimaryContainer = Color(0xFF86D881);
  static const Color primaryFixed = Color(0xFFA3F69C);
  static const Color onPrimaryFixed = Color(0xFF002204);

  static const Color secondary = Color(0xFF4C616C);
  static const Color secondaryContainer = Color(0xFFCFE6F2);
  static const Color onSecondaryContainer = Color(0xFF526772);

  static const Color tertiary = Color(0xFF6B1D3D);
  static const Color tertiaryContainer = Color(0xFF883454);
  static const Color tertiaryFixed = Color(0xFFFFD9E2);

  static const Color background = Color(0xFFF5FCED);
  static const Color onBackground = Color(0xFF171D14);
  static const Color surface = Color(0xFFF5FCED);
  static const Color onSurface = Color(0xFF171D14);
  static const Color surfaceVariant = Color(0xFFDEE5D6);
  static const Color onSurfaceVariant = Color(0xFF41493E);
  static const Color surfaceContainerLow = Color(0xFFEFF6E7);
  static const Color surfaceContainer = Color(0xFFE9F0E1);
  static const Color surfaceContainerHigh = Color(0xFFE3EBDC);
  static const Color surfaceContainerHighest = Color(0xFFDEE5D6);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color outline = Color(0xFF717A6D);
  static const Color outlineVariant = Color(0xFFC0C9BB);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryContainer,
        tertiary: AppColors.tertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w900,
          fontSize: 56,
          letterSpacing: -1.12,
          color: AppColors.primary,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w800,
          fontSize: 32,
          letterSpacing: -0.64,
          color: AppColors.primary,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: AppColors.primary,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: AppColors.onSurface,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 16,
          color: AppColors.onSurface,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: AppColors.onSurfaceVariant,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.1,
          color: AppColors.primary,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
