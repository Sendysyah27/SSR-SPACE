import 'package:flutter/material.dart';

class SsrColors {
  static const paper = Color(0xFFFAFAF7);
  static const ink = Color(0xFF1C1B1A);
  static const secondary = Color(0xFF5F5E5B);
  // Aksen lawas = emerald ledger (teal lama pensiun LP-T8).
  // Nama dipertahankan untuk SsrTheme.light() lawas.
  static const accent = AppColors.emerald;
  static const danger = Color(0xFFB3261E);
  static const accentSoft = Color(0xFFE6F3F1);
  static const dangerSoft = Color(0xFFF9E8E6);
  // Emas tabungan: makna ketiga setelah zamrud (masuk) & bata (keluar).
  // Dipakai hanya di titik tabungan (gauge, iris donut, strip dompet).
  static const saving = Color(0xFFB45309);
  static const savingSoft = Color(0xFFFBEDD3);
  static const surfaceMuted = Color(0xFFF3F2EE);
  // Token Emerald Noir dihapus LP-T8 (nol rujukan di lib/).
  // Mode gelap kini AppTheme.dark(); aksen via colorScheme.
  static const mint = Color(0xFF2DD4BF);
  static const rose = Color(0xFFF87171);
  static const gold = Color(0xFFC6A15B);
}

/// Token warna Ledger Premium (exact dari prompt desain, 2026-09-27).
/// Satu-satunya sumber hex untuk UI baru. SsrColors dipertahankan
/// hingga migrasi selesai (dihapus Task 6).
class AppColors {
  static const emerald = Color(0xFF0E4B44);
  static const emeraldDeep = Color(0xFF0A332E);
  static const gold = Color(0xFFC9A227);
  static const goldSoft = Color(0xFFEDE2C1);
  static const rust = Color(0xFFB23A2E);
  static const cream = Color(0xFFF6F4EC);
  static const ink = Color(0xFF171A19);
  static const inkSoft = Color(0xFF5B6360);
  static const line = Color(0xFFE4E0D4);
  static const bgDark = Color(0xFF12100C);
  static const surfaceDark = Color(0xFF1C1A16);
  static const inkDark = Color(0xFFF1EEE6);
  static const inkSoftDark = Color(0xFFA6A296);
  static const lineDark = Color(0xFF2C2823);
  // Emerald terang khusus dark mode (carry LP-T6): emerald exact 0E4B44
  // sebagai teks di bgDark hanya 1.91 (gagal AA), jadi peran teks/fill
  // primer dark memakai ini (7.69 dua arah dengan teks bgDark). Adaptasi
  // tercatat, bukan nilai prompt.
  static const emeraldBright = Color(0xFF45B79B);
  // Chip ledger tetap (sama kedua mode): teks surplus, bg auto, bg warning.
  static const chipSurplusText = Color(0xFF7A5E14);
  static const chipAutoBg = Color(0xFFE4EFEA);
  static const chipWarnBg = Color(0xFFF6E4E1);
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
  static const button = 12.0;
  static const card = 24.0;
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

  /// Nominal tabular tanpa warna eksplisit (ruling LP-T8): mewarisi warna
  /// teks konteks (onSurface di kartu terang, inkDark di hero gelap).
  /// Pemanggil yang butuh warna pasti memakai copyWith(warna) sendiri.
  static const money = TextStyle(
    fontFamily: SsrFonts.body,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const moneyLarge = TextStyle(
    fontFamily: SsrFonts.body,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const moneyOnDark = TextStyle(
    fontFamily: SsrFonts.body,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Theme Ledger Premium: light-first cream plus varian dark.
/// Dipakai via MaterialApp theme/darkTheme/themeMode system di main.dart.
class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.emerald,
      onPrimary: AppColors.cream,
      surface: Colors.white,
      onSurface: AppColors.ink,
      error: AppColors.rust,
      onError: AppColors.cream,
      outline: AppColors.line,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: SsrFonts.body,
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: AppColors.ink,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontFamily: SsrFonts.display,
          fontSize: 32,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
          color: AppColors.ink,
        ),
        titleLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 16,
          height: 1.5,
          color: AppColors.ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 14,
          height: 1.5,
          color: AppColors.ink,
        ),
        bodySmall: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 12,
          height: 1.4,
          color: AppColors.inkSoft,
        ),
        labelLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: AppColors.emerald,
          foregroundColor: AppColors.cream,
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
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SsrRadius.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: AppColors.emerald,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: AppColors.emerald, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(thickness: 0.8, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: SsrFonts.body,
          color: AppColors.cream,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SsrRadius.tile),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.cream;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.emerald;
          }
          return null;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.emerald,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 4),
        minTileHeight: 52,
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.emeraldBright,
      onPrimary: AppColors.bgDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.inkDark,
      error: AppColors.rust,
      onError: AppColors.inkDark,
      outline: AppColors.lineDark,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: SsrFonts.body,
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgDark,
        foregroundColor: AppColors.inkDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: AppColors.inkDark,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontFamily: SsrFonts.display,
          fontSize: 32,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
          color: AppColors.inkDark,
        ),
        titleLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: AppColors.inkDark,
        ),
        titleMedium: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.inkDark,
        ),
        bodyLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 16,
          height: 1.5,
          color: AppColors.inkDark,
        ),
        bodyMedium: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 14,
          height: 1.5,
          color: AppColors.inkDark,
        ),
        bodySmall: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 12,
          height: 1.4,
          color: AppColors.inkSoftDark,
        ),
        labelLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.inkDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: AppColors.emeraldBright,
          foregroundColor: AppColors.bgDark,
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
          foregroundColor: AppColors.inkDark,
          side: const BorderSide(color: AppColors.lineDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SsrRadius.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: AppColors.emeraldBright,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: AppColors.lineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: AppColors.lineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide:
              const BorderSide(color: AppColors.emeraldBright, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        thickness: 0.8,
        space: 1,
        color: AppColors.lineDark,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceDark,
        contentTextStyle: const TextStyle(
          fontFamily: SsrFonts.body,
          color: AppColors.inkDark,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SsrRadius.tile),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.bgDark;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.emeraldBright;
          }
          return null;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.emeraldBright,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 4),
        minTileHeight: 52,
      ),
    );
  }
}
