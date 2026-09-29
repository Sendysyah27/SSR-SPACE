import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/cool_icons.dart';

IconData iconForCategory(String? category) {
  final c = (category ?? '').toLowerCase();
  if (c.contains('makan') || c.contains('minum') || c.contains('jajan') || c.contains('kuliner')) {
    return AppIcons.food;
  }
  if (c.contains('transport') || c.contains('bensin') || c.contains('parkir') || c.contains('ojek') || c.contains('tol')) {
    return AppIcons.transport;
  }
  if (c.contains('belanja')) return AppIcons.shopping;
  if (c.contains('tagihan') || c.contains('listrik') || c.contains('air') || c.contains('internet') || c.contains('pulsa') || c.contains('kuota')) {
    return AppIcons.bills;
  }
  if (c.contains('sehat') || c.contains('obat') || c.contains('dokter')) {
    return AppIcons.health;
  }
  if (c.contains('sekolah') || c.contains('kuliah') || c.contains('kursus') || c.contains('buku')) {
    return AppIcons.education;
  }
  if (c.contains('hiburan') || c.contains('film') || c.contains('game') || c.contains('musik')) {
    return AppIcons.entertainment;
  }
  if (c.contains('gaji') || c.contains('upah') || c.contains('bonus')) {
    return AppIcons.income;
  }
  if (c.contains('topup') || c.contains('top up') || c.contains('isi saldo')) {
    return AppIcons.topup;
  }
  if (c.contains('transfer')) return AppIcons.transfer;
  return AppIcons.categoryFallback;
}

/// Path SVG kategori Ledger Premium (12 file di assets/illustrations).
/// Cabang SAMA PERSIS dengan [iconForCategory] plus wifi (sebelum tagihan)
/// dan tabungan/saving; income dan topup ke wallet; transfer ke transfer.
/// [iconForCategory] lama dipertahankan untuk layar lain hingga migrasi T6.
String svgForCategory(String? category) {
  // Kategori baru (investasi, donasi, keluarga, olahraga, hewan, darurat)
  // dicek dulu; cabang lama di bawah tak berubah perilaku.
  final cool = coolForNewCategory(category);
  if (cool != null) return cool;
  final c = (category ?? '').toLowerCase();
  if (c.contains('makan') || c.contains('minum') || c.contains('jajan') || c.contains('kuliner')) {
    return 'assets/illustrations/cat_food.svg';
  }
  if (c.contains('transport') || c.contains('bensin') || c.contains('parkir') || c.contains('ojek') || c.contains('tol')) {
    return 'assets/illustrations/cat_transport.svg';
  }
  if (c.contains('belanja')) return 'assets/illustrations/cat_shop.svg';
  if (c.contains('pulsa') || c.contains('internet') || c.contains('wifi')) {
    return 'assets/illustrations/cat_wifi.svg';
  }
  if (c.contains('tagihan') || c.contains('listrik') || c.contains('air') || c.contains('internet') || c.contains('pulsa') || c.contains('kuota')) {
    return 'assets/illustrations/cat_bill.svg';
  }
  if (c.contains('sehat') || c.contains('obat') || c.contains('dokter')) {
    return 'assets/illustrations/cat_health.svg';
  }
  if (c.contains('sekolah') || c.contains('kuliah') || c.contains('kursus') || c.contains('buku')) {
    return 'assets/illustrations/cat_edu.svg';
  }
  if (c.contains('hiburan') || c.contains('film') || c.contains('game') || c.contains('musik')) {
    return 'assets/illustrations/cat_fun.svg';
  }
  if (c.contains('tabungan') || c.contains('saving')) {
    return 'assets/illustrations/cat_save.svg';
  }
  if (c.contains('gaji') || c.contains('upah') || c.contains('bonus')) {
    return 'assets/illustrations/cat_wallet.svg';
  }
  if (c.contains('topup') || c.contains('top up') || c.contains('isi saldo')) {
    return 'assets/illustrations/cat_wallet.svg';
  }
  if (c.contains('transfer')) return 'assets/illustrations/cat_transfer.svg';
  return 'assets/illustrations/cat_other.svg';
}

/// SVG untuk kunci ikon hasil kustomisasi user (picker kategori).
/// Kunci di luar daftar dikenal jatuh ke cat_other (tak pernah throw).
String svgForMetaIcon(String key) {
  switch (key) {
    case 'food':
      return 'assets/illustrations/cat_food.svg';
    case 'transport':
      return 'assets/illustrations/cat_transport.svg';
    case 'shopping':
      return 'assets/illustrations/cat_shop.svg';
    case 'bills':
      return 'assets/illustrations/cat_bill.svg';
    case 'health':
      return 'assets/illustrations/cat_health.svg';
    case 'education':
      return 'assets/illustrations/cat_edu.svg';
    case 'entertainment':
      return 'assets/illustrations/cat_fun.svg';
    case 'topup':
    case 'income':
    case 'wallet':
      return 'assets/illustrations/cat_wallet.svg';
    case 'transfer':
      return 'assets/illustrations/cat_transfer.svg';
    default:
      return 'assets/illustrations/cat_other.svg';
  }
}

/// Palet 8 warna kategori (sama persis dengan picker layar kategori).
/// Slot 0..2 ikut tema (primary/error/gold), sisanya fixed.
Color metaSlotColor(BuildContext context, int index) {
  final scheme = Theme.of(context).colorScheme;
  switch (index) {
    case 0:
      return scheme.primary;
    case 1:
      return scheme.error;
    case 2:
      return AppColors.gold;
    case 3:
      return const Color(0xFF2563EB);
    case 4:
      return const Color(0xFF7C3AED);
    case 5:
      return const Color(0xFFDB2777);
    case 6:
      return const Color(0xFF65A30D);
    default:
      return const Color(0xFF64748B);
  }
}
