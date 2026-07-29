import 'package:flutter/material.dart';

/// Editorial light palette: warm cream background, near-black charcoal text,
/// white cards with hairline borders, and warm accent colors.
class AppColors {
  // Backgrounds / surfaces
  static const backgroundPrimary = Color(0xFFF8FAFC); // soft slate/white page
  static const surfaceAlt = Color(0xFFF1F5F9); // soft grayish blue surface
  static const glassSurface = Color(0xFFFFFFFF); // pure white cards
  static const glassBorder = Color(0xFFE2E8F0); // subtle modern light border

  // Sidebar colors
  static const sidebarBackground = Color(0xFFFFFFFF); // white sidebar
  static const sidebarSelected = Color(0xFFF1F5F9); // selected nav pill background
  static const sidebarBorder = Color(0xFFF1F5F9); // subtle divider

  // Text
  static const textPrimary = Color(0xFF0F172A); // dark slate / charcoal
  static const textMuted = Color(0xFF64748B); // slate gray

  // Accents
  static const ink = Color(0xFF0F172A); // dark pill buttons / active tabs
  static const accentViolet = Color(0xFF4F46E5); // indigo (primary accent)
  static const accentCyan = Color(0xFF0D9488); // teal (secondary accent)
  static const accentAmber = Color(0xFFD97706);
  static const accentCoral = Color(0xFFE11D48);
  static const accentPink = Color(0xFFDB2777);

  // Status
  static const errorRed = Color(0xFFEF4444);
  static const successGreen = Color(0xFF10B981);
}

