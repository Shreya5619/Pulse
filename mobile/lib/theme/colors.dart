import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF060609);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceVariant = Color(0xFF1E1E2A);
  
  static const Color primary = Color(0xFF00D2FF); // Electric Blue
  static const Color secondary = Color(0xFF0072FF); // Deep Blue
  static const Color accent = Color(0xFF4A90E2);
  
  static const Color success = Color(0xFF00F5A0);
  static const Color warning = Color(0xFFFDC830);
  static const Color danger = Color(0xFFFF4B2B);
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0CC);
  static const Color textMuted = Color(0xFF6E6E80);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [background, Color(0xFF0A0A12)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x1A00D2FF), // Transparent Electric Blue
      Color(0x0D00D2FF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
