import 'package:flutter/material.dart';

/// Keluarga font Phosphor Duotone yang dibundel (lihat pubspec).
const String kPhosphorDuotoneFamily = 'PhosphorDuotone';

/// Peta semantik ikon aplikasi ke Phosphor duotone.
///
/// Font divendor langsung (tanpa paket `phosphor_flutter` yang tak kompatibel
/// dengan Flutter stable kini: `IconData` sudah `final`). Render lewat widget
/// [DuoIcon], bukan `Icon`: hanya [DuoIcon] yang menggambar lapisan sekunder
/// pada opacity 20% (tint zamrud lembut), sesuai token desain.
class AppIcons {
  AppIcons._();

  // Navigasi bawah & aksi utama
  static final home = IconData(0xe2c3, fontFamily: kPhosphorDuotoneFamily);
  static final transactions = IconData(0xe3f1, fontFamily: kPhosphorDuotoneFamily);
  static final budget = IconData(0xea05, fontFamily: kPhosphorDuotoneFamily);
  static final reports = IconData(0xe151, fontFamily: kPhosphorDuotoneFamily);
  static final menu = IconData(0xe465, fontFamily: kPhosphorDuotoneFamily);
  static final add = IconData(0xe3d5, fontFamily: kPhosphorDuotoneFamily);

  // Kategori transaksi (pengganti Material di category_icons)
  static final food = IconData(0xe263, fontFamily: kPhosphorDuotoneFamily);
  static final transport = IconData(0xe113, fontFamily: kPhosphorDuotoneFamily);
  static final shopping = IconData(0xe419, fontFamily: kPhosphorDuotoneFamily);
  static final bills = IconData(0xe3f1, fontFamily: kPhosphorDuotoneFamily);
  static final health = IconData(0xe2a9, fontFamily: kPhosphorDuotoneFamily);
  static final education = IconData(0xe62d, fontFamily: kPhosphorDuotoneFamily);
  static final entertainment = IconData(0xe8c3, fontFamily: kPhosphorDuotoneFamily);
  static final income = IconData(0xe54d, fontFamily: kPhosphorDuotoneFamily);
  static final topup = IconData(0xe467, fontFamily: kPhosphorDuotoneFamily);
  static final transfer = IconData(0xe0a1, fontFamily: kPhosphorDuotoneFamily);
  static final categoryFallback = IconData(0xec5f, fontFamily: kPhosphorDuotoneFamily);

  // Arah transaksi
  static final txIn = IconData(0xe041, fontFamily: kPhosphorDuotoneFamily);
  static final txOut = IconData(0xe093, fontFamily: kPhosphorDuotoneFamily);
  static final arrowDown = IconData(0xe03f, fontFamily: kPhosphorDuotoneFamily);
  static final arrowUp = IconData(0xe08f, fontFamily: kPhosphorDuotoneFamily);
  static final autoBadge = IconData(0xe2df, fontFamily: kPhosphorDuotoneFamily);

  // Dompet
  static final wallet = IconData(0xe68b, fontFamily: kPhosphorDuotoneFamily);
  static final walletCash = IconData(0xe589, fontFamily: kPhosphorDuotoneFamily);
  static final walletEwallet = IconData(0xe1e1, fontFamily: kPhosphorDuotoneFamily);
  static final walletBank = IconData(0xe0b5, fontFamily: kPhosphorDuotoneFamily);

  // Menu Lainnya & utilitas
  static final workspace = IconData(0xe105, fontFamily: kPhosphorDuotoneFamily);
  static final workspaceSwitch = IconData(0xe0a1, fontFamily: kPhosphorDuotoneFamily);
  static final invite = IconData(0xe68f, fontFamily: kPhosphorDuotoneFamily);
  static final tracking = IconData(0xe0cf, fontFamily: kPhosphorDuotoneFamily);
  static final backup = IconData(0xe20d, fontFamily: kPhosphorDuotoneFamily);
  static final billing = IconData(0xe1d3, fontFamily: kPhosphorDuotoneFamily);
  static final logout = IconData(0xe42b, fontFamily: kPhosphorDuotoneFamily);
  static final revoke = IconData(0xe2e9, fontFamily: kPhosphorDuotoneFamily);
  static final scan = IconData(0xe095, fontFamily: kPhosphorDuotoneFamily);
  static final monthPrev = IconData(0xe139, fontFamily: kPhosphorDuotoneFamily);
  static final monthNext = IconData(0xe13b, fontFamily: kPhosphorDuotoneFamily);
  static final chevron = IconData(0xe13b, fontFamily: kPhosphorDuotoneFamily);
  static final eye = IconData(0xe221, fontFamily: kPhosphorDuotoneFamily);
  static final eyeOff = IconData(0xe225, fontFamily: kPhosphorDuotoneFamily);
  static final error = IconData(0xe1b7, fontFamily: kPhosphorDuotoneFamily);
  static final lock = IconData(0xe2fb, fontFamily: kPhosphorDuotoneFamily);
  static final addUser = IconData(0xe4d1, fontFamily: kPhosphorDuotoneFamily);
  static final success = IconData(0xe607, fontFamily: kPhosphorDuotoneFamily);

  /// Codepoint lapisan sekunder per lapisan primer.
  static const _subs = <int, int>{
    0xe2c3: 0xe2c2,
    0xe3f1: 0xe3ec,
    0xea05: 0xea04,
    0xe151: 0xe150,
    0xe465: 0xe464,
    0xe3d5: 0xe3d4,
    0xe263: 0xe262,
    0xe113: 0xe112,
    0xe419: 0xe418,
    0xe2a9: 0xe2a8,
    0xe62d: 0xe62c,
    0xe8c3: 0xe8c2,
    0xe54d: 0xe54c,
    0xe467: 0xe466,
    0xe0a1: 0xe0a0,
    0xec5f: 0xec5e,
    0xe041: 0xe040,
    0xe093: 0xe092,
    0xe03f: 0xe03e,
    0xe08f: 0xe08e,
    0xe2df: 0xe2de,
    0xe68b: 0xe68a,
    0xe589: 0xe588,
    0xe1e1: 0xe1e0,
    0xe0b5: 0xe0b4,
    0xe105: 0xe102,
    0xe68f: 0xe68e,
    0xe0cf: 0xe0ce,
    0xe20d: 0xe20c,
    0xe1d3: 0xe1d2,
    0xe42b: 0xe42a,
    0xe2e9: 0xe2e8,
    0xe095: 0xe094,
    0xe139: 0xe138,
    0xe13b: 0xe13a,
    0xe221: 0xe220,
    0xe225: 0xe224,
    0xe1b7: 0xe1b6,
    0xe2fb: 0xe2fa,
    0xe4d1: 0xe4d0,
    0xe607: 0xe606,
  };

  /// Lapisan sekunder untuk [icon] (diri sendiri bila tak dikenal).
  static IconData subOf(IconData icon) => _subIcons[icon.codePoint] ?? icon;

  static final Map<int, IconData> _subIcons = {
    for (final e in _subs.entries)
      e.key: IconData(e.value, fontFamily: kPhosphorDuotoneFamily),
  };
}

/// Ikon duotone: lapisan sekunder di bawah pada opacity 20%.
class DuoIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final double secondaryOpacity;

  const DuoIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.secondaryOpacity = 0.20,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: secondaryOpacity,
          child: Icon(AppIcons.subOf(icon), size: size, color: c),
        ),
        Icon(icon, size: size, color: c),
      ],
    );
  }
}
