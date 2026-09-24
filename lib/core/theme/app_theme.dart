import 'package:flutter/material.dart';

class SsrColors {
  static const paper = Color(0xFFFAFAF7);
  static const ink = Color(0xFF1C1B1A);
  static const secondary = Color(0xFF5F5E5B);
  static const accent = Color(0xFF0F766E);
  static const danger = Color(0xFFB3261E);
}

class SsrTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: SsrColors.accent,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: SsrColors.ink,
      error: SsrColors.danger,
      onError: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: SsrColors.paper,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: SsrColors.paper,
        foregroundColor: SsrColors.ink,
        elevation: 0,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: SsrColors.ink),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: SsrColors.ink),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: SsrColors.ink),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: SsrColors.ink),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: SsrColors.ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: SsrColors.ink),
        bodySmall: TextStyle(fontSize: 12, color: SsrColors.secondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(thickness: 0.8, space: 1),
    );
  }

  static const money = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: SsrColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const moneyLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: SsrColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
