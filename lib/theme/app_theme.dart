import 'package:flutter/material.dart';

/// Token warna Ledger Premium (exact dari prompt desain, 2026-09-27).
/// Satu-satunya sumber hex untuk UI baru.
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

/// Token Industrial iPhone (2026-10-14, disetujui owner): chrome netral
/// premium, satu aksen biru. Alasan tiap nilai:
/// - scaffold/surface abu iOS (grup + kartu terbaca tanpa border tebal).
/// - teks sekunder #6E6E73 di putih ≈5.0 (AA); dark #98989D di hitam aman.
/// - aksen #007AFF (putih di atasnya ≈4.5); dark #0A84FF.
/// - radius 20 kartu / 14 kecil-input / 999 pill / 14 tombol (R-11).
/// - bayangan SATU level 0/8/24 6% untuk hero/kartu terangkat (R-12).
/// Warna makna uang (emerald/rust/gold) TIDAK diubah: tetap untuk
/// masuk/keluar/tabungan + label kata.
class Ind {
  static const scaffoldL = Color(0xFFF2F2F7);
  static const card2L = Color(0xFFF9F9FB);
  static const ink = Color(0xFF1C1C1E);
  static const secondaryL = Color(0xFF6E6E73);
  static const lineL = Color(0xFFE5E5EA);
  static const blue = Color(0xFF007AFF);
  static const scaffoldD = Color(0xFF000000);
  static const surfaceD = Color(0xFF1C1C1E);
  static const inkD = Color(0xFFF5F5F7);
  static const secondaryD = Color(0xFF98989D);
  static const lineD = Color(0xFF38383A);
  static const blueD = Color(0xFF0A84FF);
  // Semantik iOS (brief §1.1): KHUSUS grafik/fill besar, BUKAN teks
  // (di putih gagal AA: green ±2.2, orange ±2.1). Teks makna tetap
  // emerald/rust/gold-dark yang lolos AA. Deviasi tercatat (R-37).
  static const green = Color(0xFF30D158);
  static const red = Color(0xFFFF453A);
  static const orange = Color(0xFFFF9F0A);

  static List<BoxShadow> heroShadow(bool dark) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}

class SsrMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;
}

class SsrRadius {
  static const chip = 8.0;
  static const input = 14.0;
  static const tile = 14.0;
  static const button = 14.0;
  static const card = 20.0;
  static const hero = 20.0;
  static const pill = 999.0;
}

class SsrSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

class SsrFonts {
  static const body = 'PlusJakartaSans';
  static const display = 'Anton';
  static const numeric = 'Fraunces';
  static const icon = 'PhosphorFill';
}

/// Theme Ledger Premium: light-first cream plus varian dark.
/// Dipakai via MaterialApp theme/darkTheme/themeMode system di main.dart.
class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: Ind.blue,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: Ind.ink,
      error: AppColors.rust,
      onError: Colors.white,
      outline: Ind.lineL,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: SsrFonts.body,
      scaffoldBackgroundColor: Ind.scaffoldL,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Ind.scaffoldL,
        foregroundColor: Ind.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: Ind.ink,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontFamily: SsrFonts.display,
          fontSize: 32,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
          color: Ind.ink,
        ),
        titleLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: Ind.ink,
        ),
        titleMedium: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Ind.ink,
        ),
        bodyLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 16,
          height: 1.5,
          color: Ind.ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 14,
          height: 1.5,
          color: Ind.ink,
        ),
        bodySmall: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 12,
          height: 1.4,
          color: Ind.secondaryL,
        ),
        labelLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Ind.ink,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: Ind.blue,
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
          foregroundColor: Ind.ink,
          side: const BorderSide(color: Ind.lineL),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SsrRadius.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: Ind.blue,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: Ind.lineL),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: Ind.lineL),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: Ind.blue, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(thickness: 0.8, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Ind.ink,
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
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Ind.blue;
          }
          return null;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Ind.blue,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 4),
        minTileHeight: 52,
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: Ind.blueD,
      onPrimary: Colors.white,
      surface: Ind.surfaceD,
      onSurface: Ind.inkD,
      error: AppColors.rust,
      onError: Ind.inkD,
      outline: Ind.lineD,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: SsrFonts.body,
      scaffoldBackgroundColor: Ind.scaffoldD,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Ind.scaffoldD,
        foregroundColor: Ind.inkD,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: Ind.inkD,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontFamily: SsrFonts.display,
          fontSize: 32,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
          color: Ind.inkD,
        ),
        titleLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: Ind.inkD,
        ),
        titleMedium: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Ind.inkD,
        ),
        bodyLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 16,
          height: 1.5,
          color: Ind.inkD,
        ),
        bodyMedium: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 14,
          height: 1.5,
          color: Ind.inkD,
        ),
        bodySmall: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 12,
          height: 1.4,
          color: Ind.secondaryD,
        ),
        labelLarge: TextStyle(
          fontFamily: SsrFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Ind.inkD,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: Ind.blueD,
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
          foregroundColor: Ind.inkD,
          side: const BorderSide(color: Ind.lineD),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SsrRadius.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          foregroundColor: Ind.blueD,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Ind.surfaceD,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: Ind.lineD),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(color: Ind.lineD),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsrRadius.input),
          borderSide: const BorderSide(
            color: Ind.blueD,
            width: 1.6,
          ),
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
        backgroundColor: Ind.surfaceD,
        contentTextStyle: const TextStyle(
          fontFamily: SsrFonts.body,
          color: Ind.inkD,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SsrRadius.tile),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Ind.blueD;
          }
          return null;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Ind.blueD,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 4),
        minTileHeight: 52,
      ),
    );
  }

  /// Nominal tabular tanpa warna eksplisit (ruling LP-T8): mewarisi warna
  /// teks konteks (onSurface di kartu terang, inkDark di hero gelap).
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
