import 'package:flutter/material.dart';
import 'app_colors.dart';

class GlassTheme {
  /// Editorial light theme (cream/charcoal). Kept as `darkTheme` for compat.
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundPrimary,
      primaryColor: AppColors.ink,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.light(
        primary: AppColors.ink,
        secondary: AppColors.accentViolet,
        error: AppColors.errorRed,
        surface: AppColors.glassSurface,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        labelLarge: TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
