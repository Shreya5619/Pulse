import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF060609);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceVariant = Color(0xFF1E1E2A);
  
  static const Color primary = Color(0xFF00E5FF);
  static const Color secondary = Color(0xFFB388FF);
  static const Color accent = Color(0xFF7C4DFF);
  
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFAB40);
  static const Color danger = Color(0xFFFF5252);
  
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF666666);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surface, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
