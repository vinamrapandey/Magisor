import 'package:flutter/material.dart';

/// Editorial light palette: warm cream background, near-black charcoal text,
/// white cards with hairline borders, and warm accent colors.
class AppColors {
  // Backgrounds / surfaces
  static const backgroundPrimary = Color(0xFFF4F1EA); // cream page
  static const surfaceAlt = Color(0xFFEAE6DD); // slightly darker cream
  static const glassSurface = Color(0xFFFFFFFF); // white cards (name kept for compat)
  static const glassBorder = Color(0x14000000); // hairline dark ~8%

  // Text
  static const textPrimary = Color(0xFF1C1C1A); // charcoal
  static const textMuted = Color(0xFF8A867C); // warm gray

  // Accents
  static const ink = Color(0xFF232320); // dark pill buttons / active tabs
  static const accentViolet = Color(0xFF4F46E5); // indigo (primary accent)
  static const accentCyan = Color(0xFF0F9E75); // teal (secondary accent)
  static const accentAmber = Color(0xFFBA7517);
  static const accentCoral = Color(0xFFD85A30);
  static const accentPink = Color(0xFFD4537E);

  // Status
  static const errorRed = Color(0xFFD85A30); // coral, on-palette
  static const successGreen = Color(0xFF0F9E75);
}
