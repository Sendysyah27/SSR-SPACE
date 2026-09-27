import 'package:flutter/material.dart';

class SsrColors {
  static const paper = Color(0xFFFAFAF7);
  static const ink = Color(0xFF1C1B1A);
  static const secondary = Color(0xFF5F5E5B);
  static const accent = Color(0xFF0F766E);
  static const danger = Color(0xFFB3261E);
  static const accentSoft = Color(0xFFE6F3F1);
  static const dangerSoft = Color(0xFFF9E8E6);
  // Emas tabungan: makna ketiga setelah zamrud (masuk) & bata (keluar).
  // Dipakai hanya di titik tabungan (gauge, iris donut, strip dompet).
  static const saving = Color(0xFFB45309);
  static const savingSoft = Color(0xFFFBEDD3);
  static const surfaceMuted = Color(0xFFF3F2EE);
  // Token Emerald Noir (identitas gelap, dipakai SsrTheme.noir()).
  static const noirBg = Color(0xFF0C1210);
  static const noirSurface = Color(0xFF141C18);
  static const noirRaised = Color(0xFF1B2521);
  static const noirLine = Color(0xFF2A3530);
  static const noirInk = Color(0xFFF2EFE6);
  static const noirSecondary = Color(0xFFA8A39A);
  static const mint = Color(0xFF2DD4BF);
  static const rose = Color(0xFFF87171);
  static const gold = Color(0xFFC6A15B);
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

class SsrFonts {
  static const body = 'PlusJakartaSans';
  static const display = 'Anton';
  static const numeric = 'Fraunces';
  static const icon = 'PhosphorFill';
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
      fontFamily: SsrFonts.body,
      scaffoldBackgroundColor: SsrColors.paper,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: SsrColors.paper,
        foregroundColor: SsrColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: SsrColors.ink,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontFamily: SsrFonts.display,
          fontSize: 32,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
          color: SsrColors.ink,
        ),
        titleLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: SsrColors.ink,
        ),
        titleMedium: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: SsrColors.ink,
        ),
        bodyLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 16,
          height: 1.5,
          color: SsrColors.ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 14,
          height: 1.5,
          color: SsrColors.ink,
        ),
        bodySmall: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 12,
          height: 1.4,
          color: SsrColors.secondary,
        ),
        labelLarge: TextStyle(
          fontFamily: SsrFonts.body,
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
          textStyle: const TextStyle(
            fontFamily: SsrFonts.body,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
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
        contentTextStyle: const TextStyle(
          fontFamily: SsrFonts.body,
          color: Colors.white,
          fontSize: 14,
        ),
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

  static ThemeData noir() {
    const scheme = ColorScheme.dark(
      primary: SsrColors.mint,
      onPrimary: Color(0xFF0C1210),
      surface: SsrColors.noirSurface,
      onSurface: SsrColors.noirInk,
      error: SsrColors.rose,
      onError: Color(0xFF0C1210),
      outline: SsrColors.noirLine,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: SsrFonts.body,
      scaffoldBackgroundColor: SsrColors.noirBg,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: SsrColors.noirBg,
        foregroundColor: SsrColors.noirInk,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: SsrColors.noirInk,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontFamily: SsrFonts.display,
          fontSize: 32,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
          color: SsrColors.noirInk,
        ),
        titleLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: SsrColors.noirInk,
        ),
        titleMedium: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: SsrColors.noirInk,
        ),
        bodyLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 16,
          height: 1.5,
          color: SsrColors.noirInk,
        ),
        bodyMedium: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 14,
          height: 1.5,
          color: SsrColors.noirInk,
        ),
        bodySmall: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 12,
          height: 1.4,
          color: SsrColors.noirSecondary,
        ),
        labelLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: SsrColors.noirInk,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: SsrColors.mint,
          foregroundColor: Color(0xFF0C1210),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SsrRadius.button),
          ),
          textStyle: const TextStyle(
            fontFamily: SsrFonts.body,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: SsrColors.noirInk,
          side: const BorderSide(color: SsrColors.noirLine),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SsrRadius.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: SsrColors.mint,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SsrColors.noirSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: SsrColors.noirLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: SsrColors.noirLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: SsrColors.mint, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 0.8,
        space: 1,
        color: SsrColors.noirLine,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: SsrColors.noirRaised,
        contentTextStyle: const TextStyle(
          fontFamily: SsrFonts.body,
          color: SsrColors.noirInk,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SsrRadius.tile),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF0C1210);
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return SsrColors.mint;
          return null;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SsrColors.mint,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 4),
        minTileHeight: 52,
      ),
    );
  }

  static const money = TextStyle(
    fontFamily: SsrFonts.body,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: SsrColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const moneyLarge = TextStyle(
    fontFamily: SsrFonts.body,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: SsrColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const moneyOnDark = TextStyle(
    fontFamily: SsrFonts.body,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: Colors.white,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
