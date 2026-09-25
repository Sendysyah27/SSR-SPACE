import 'package:flutter/material.dart';

class SsrColors {
  static const paper = Color(0xFFFAFAF7);
  static const ink = Color(0xFF1C1B1A);
  static const secondary = Color(0xFF5F5E5B);
  static const accent = Color(0xFF0F766E);
  static const danger = Color(0xFFB3261E);
  static const accentSoft = Color(0xFFE6F3F1);
  static const dangerSoft = Color(0xFFF9E8E6);
  static const surfaceMuted = Color(0xFFF3F2EE);
}

class SsrMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;
}

class SsrRadius {
  static const chip = 8.0;
  static const input = 12.0;
  static const tile = 12.0;
  static const button = 14.0;
  static const card = 16.0;
  static const hero = 24.0;
}

class SsrSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
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
      outline: Color(0xFFD9D7D0),
    );
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: SsrColors.paper,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: SsrColors.paper,
        foregroundColor: SsrColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: SsrColors.ink,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: SsrColors.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: SsrColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: SsrColors.ink,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: SsrColors.ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: SsrColors.ink),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: SsrColors.secondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: SsrColors.ink,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: SsrColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SsrRadius.button),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: SsrColors.ink,
          side: const BorderSide(color: Color(0xFFD9D7D0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SsrRadius.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: SsrColors.accent,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: Color(0xFFD9D7D0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: Color(0xFFD9D7D0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: SsrColors.accent, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(thickness: 0.8, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: SsrColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SsrRadius.tile),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return SsrColors.accent;
          return null;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SsrColors.accent,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 4),
        minTileHeight: 52,
      ),
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
  static const moneyOnDark = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: Colors.white,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
