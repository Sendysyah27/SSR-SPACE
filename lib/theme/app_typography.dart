import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Tipografi display angka (Fraunces) untuk nominal tunggal yang besar.
/// Angka kolom (list transaksi, saldo dompet, kartu laporan) tetap
/// Plus Jakarta Sans, karena Fraunces tidak punya fitur `tnum`
/// dan digitnya bisa meleset sejajar.
///
/// Tanpa warna eksplisit: mewarisi warna teks theme (ink light,
/// inkDark dark) kecuali pemanggil copyWith warna sendiri.
class SsrType {
  /// Nominal hero di kartu gelap Beranda.
  static const heroMoney = TextStyle(
    fontFamily: SsrFonts.numeric,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Nominal besar di atas kertas (selisih Laporan, pusat donut).
  static const moneyLarge = TextStyle(
    fontFamily: SsrFonts.numeric,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Nominal budget per kategori ("Rp x dari Rp y").
  static const moneyMedium = TextStyle(
    fontFamily: SsrFonts.numeric,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
