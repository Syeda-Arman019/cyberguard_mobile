import 'package:flutter/material.dart';

class CyberColors {
  CyberColors._();

  // Backgrounds
  static const Color bgDark = Color(0xFF0A0E21);
  static const Color bgSurface = Color(0xFF13172D);
  static const Color cardBg = Color(0xFF161B33);
  static const Color cardBgElevated = Color(0xFF1E2242);

  // Borders & Dividers
  static const Color border = Color(0xFF282E54);
  static const Color borderSubtle = Color(0xFF1E2342);

  // Accents
  static const Color cyan = Color(0xFF00E5FF);
  static const Color purple = Color(0xFF7C4DFF);
  static const Color blue = Color(0xFF2979FF);

  // Risk Indicators
  static const Color safe = Color(0xFF00E676);
  static const Color suspicious = Color(0xFFFFB300);
  static const Color malicious = Color(0xFFFF1744);

  // Typography
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF78909C);

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0A0E21), Color(0xFF11152C), Color(0xFF1A1F3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF161B33), Color(0xFF1A1F3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class CyberTheme {
  CyberTheme._();

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: CyberColors.bgDark,
      primaryColor: CyberColors.cyan,
      colorScheme: const ColorScheme.dark(
        primary: CyberColors.cyan,
        secondary: CyberColors.purple,
        surface: CyberColors.cardBg,
        error: CyberColors.malicious,
        onPrimary: CyberColors.bgDark,
        onSurface: CyberColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: CyberColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: CyberColors.cyan),
      ),
      cardTheme: CardThemeData(
        color: CyberColors.cardBg,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CyberColors.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: CyberColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: CyberColors.border, width: 1.2),
        ),
        titleTextStyle: const TextStyle(
          color: CyberColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: CyberColors.textSecondary,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CyberColors.cyan,
          foregroundColor: CyberColors.bgDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CyberColors.cyan,
          side: const BorderSide(color: CyberColors.cyan, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
