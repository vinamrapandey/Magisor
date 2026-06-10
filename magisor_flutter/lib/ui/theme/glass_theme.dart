import 'package:flutter/material.dart';
import 'app_colors.dart';

class GlassTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundPrimary,
      primaryColor: AppColors.accentViolet,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentViolet,
        secondary: AppColors.accentCyan,
        error: AppColors.errorRed,
        background: AppColors.backgroundPrimary,
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