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

  static IconData _d(int codePoint) =>
      IconData(codePoint, fontFamily: kPhosphorDuotoneFamily);

  // Navigasi bawah & aksi utama
  static final home = _d(0xe2c3);
  static final transactions = _d(0xe3f1);
  static final budget = _d(0xea05);
  static final reports = _d(0xe151);
  static final menu = _d(0xe465);
  static final add = _d(0xe3d5);

  // Kategori transaksi (pengganti Material di category_icons)
  static final food = _d(0xe263);
  static final transport = _d(0xe113);
  static final shopping = _d(0xe419);
  static final bills = _d(0xe3f1);
  static final health = _d(0xe2a9);
  static final education = _d(0xe62d);
  static final entertainment = _d(0xe8c3);
  static final income = _d(0xe54d);
  static final topup = _d(0xe467);
  static final transfer = _d(0xe0a1);
  static final categoryFallback = _d(0xec5f);

  // Arah transaksi
  static final txIn = _d(0xe041);
  static final txOut = _d(0xe093);
  static final arrowDown = _d(0xe03f);
  static final arrowUp = _d(0xe08f);
  static final autoBadge = _d(0xe2df);

  // Dompet
  static final wallet = _d(0xe68b);
  static final walletCash = _d(0xe589);
  static final walletEwallet = _d(0xe1e1);
  static final walletBank = _d(0xe0b5);

  // Menu Lainnya & utilitas
  static final workspace = _d(0xe105);
  static final workspaceSwitch = _d(0xe0a1);
  static final invite = _d(0xe68f);
  static final tracking = _d(0xe0cf);
  static final backup = _d(0xe20d);
  static final billing = _d(0xe1d3);
  static final logout = _d(0xe42b);
  static final revoke = _d(0xe2e9);
  static final scan = _d(0xe095);
  static final monthPrev = _d(0xe139);
  static final monthNext = _d(0xe13b);
  static final chevron = _d(0xe13b);
  static final eye = _d(0xe221);
  static final eyeOff = _d(0xe225);
  static final error = _d(0xe1b7);
  static final lock = _d(0xe2fb);
  static final addUser = _d(0xe4d1);
  static final success = _d(0xe607);

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
  static IconData subOf(IconData icon) {
    final sub = _subs[icon.codePoint];
    if (sub == null) return icon;
    return IconData(sub, fontFamily: icon.fontFamily);
  }
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
