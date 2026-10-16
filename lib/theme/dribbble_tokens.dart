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
/// DILARANG: ungu/indigo di mana pun pada gaya baru.
abstract final class DribTokens {
  /// Latar aplikasi: biru-abu muda.
  static const Color bg = Color(0xFFEAF0F8);

  /// Permukaan kartu: putih.
  static const Color card = Color(0xFFFFFFFF);

  /// Biru utama: tombol, aksen, link.
  static const Color primary = Color(0xFF5B9BF5);

  /// Navy teks/ikon gelap.
  static const Color navy = Color(0xFF12285A);

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
