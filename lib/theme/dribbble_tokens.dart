import 'package:flutter/material.dart';

/// Design tokens TAHAP 1 restyle (referensi Dribbble banking).
///
/// SATU-SATUNYA sumber gaya baru. Tahap ini HANYA definisi — layar lama
/// tidak diubah, tidak ada behavior berubah, tidak ada library baru.
///
/// Palet (final, jangan tambah warna di luar ini tanpa revisi desain):
/// - [bg]: latar aplikasi.
/// - [card]: permukaan kartu.
/// - [primary]: biru utama (tombol, aksen, link).
/// - [navy]/[navyDeep]/[navyBright]: teks gelap + gradient.
/// - [accentOrange]: KHUSUS badge kecil (dilarang untuk tombol/teks besar).
///
/// Ungu/pink HANYA untuk ikon kategori pastel (bukan tombol/teks besar).
abstract final class DribTokens {
  /// Latar aplikasi: biru-abu muda.
  static const Color bg = Color(0xFFEAF0F8);

  /// Permukaan kartu: putih.
  static const Color card = Color(0xFFFFFFFF);

  /// Latar aplikasi sadar-tema: gelap (navy malam) saat mode dark.
  static Color bgOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0D1526)
          : bg;

  /// Permukaan kartu sadar-tema: gelap (navy malam) saat mode dark.
  static Color cardOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF16203A)
          : card;

  /// Biru utama: tombol, aksen, link.
  static const Color primary = Color(0xFF5B9BF5);

  /// Navy teks/ikon gelap.
  static const Color navy = Color(0xFF10224E);

  /// Ujung gelap gradient kartu saldo & input nominal.
  static const Color navyDeep = Color(0xFF0B1B3F);

  /// Ujung terang gradient kartu saldo & input nominal.
  static const Color navyBright = Color(0xFF1F3C88);

  /// Oranye KHUSUS badge kecil.
  static const Color accentOrange = Color(0xFFF5A55B);

  /// Teks di atas gradient navy.
  static const Color onNavy = Color(0xFFFFFFFF);

  /// Radius kartu.
  static const double cardRadius = 20;

  /// Radius sheet/dialog besar.
  static const double sheetRadius = 24;

  /// Bayangan kartu: sangat halus (hitam 7%, blur 20, y 6).
  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 20,
          offset: Offset(0, 6),
        ),
      ];

  /// Gradient kartu saldo & input nominal (navyDeep -> navyBright).
  /// Teks di atasnya selalu [onNavy].
  static const LinearGradient balanceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDeep, navyBright],
  );

  /// Varian gradient "ocean": navy -> teal gelap, diagonal topLeft-bottomRight.
  /// Teks di atasnya selalu [onNavy].
  static const LinearGradient oceanDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, Color(0xFF0B4F4A)],
  );

  /// Varian gradient "midnight": navyDeep -> biru-hitam, diagonal
  /// topLeft-bottomRight. Teks di atasnya selalu [onNavy].
  static const LinearGradient midnightBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDeep, Color(0xFF101E42)],
  );

  /// Varian gradient "steel": biru-abu -> navyBright, diagonal
  /// topLeft-bottomRight. Teks di atasnya selalu [onNavy].
  static const LinearGradient steelBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B5B8C), navyBright],
  );

  /// Teks sekunder di atas kartu putih.
  static const Color textSecondary = Color(0xFF42557C);

  /// Bolder aksi utama (hover/penting), tetap satu keluarga biru.
  static const Color primaryStrong = Color(0xFF2E6BE6);

  /// Tint biru terang untuk latar elemen non-hazard (particle/alert).
  static const Color blueLight = Color(0xFFD6E7FF);

  /// Border kartu/sepertor.
  static const Color border = Color(0xFFB9CBEF);

  /// Teks aksen di surface terang (a11y).
  static const Color accentOrangeText = Color(0xFFD97316);
  static const Color accentOrangeTextDark = Color(0xFFB96A12);

  /// Badge/tint aksen non-bahaya.
  static const Color accentOrangeBg = Color(0xFFFDEBD3);

  static const Color success = Color(0xFF2FBF8F);
  static const Color successText = Color(0xFF12805C);

  static const Color error = Color(0xFFE05252);
  static const Color errorText = Color(0xFFB3373C);

  /// Ungu/pink HANYA untuk badge kategori pastel, bukan tombol/CTA.
  static const Color purple = Color(0xFF6D4BD8);
  static const Color purpleBg = Color(0xFFE4DCFF);
  static const Color pink = Color(0xFFC2437E);
  static const Color pinkBg = Color(0xFFFFD9E8);

  /// Nama family font (sudah dibundel di assets/fonts).
  static const String fontFamily = 'PlusJakartaSans';

  /// Gaya angka besar: tebal + tabular (kolom rata, tak goyang).
  static TextStyle bigNumber({
    double size = 32,
    Color color = navy,
    FontWeight weight = FontWeight.w800,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

/// Format Rupiah standar BI: "Rp 1.250.000" (spasi setelah Rp).
/// Pemakaian nominal tetap lewat amt()/rp() yang sudah disesuaikan;
/// konstanta ini hanya dokumentasi kontrak + prefix untuk rakitan manual.
const dribRupiahPrefix = 'Rp ';
