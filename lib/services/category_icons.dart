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

/// Path SVG badge kategori: Coolicons subset (satu keluarga dengan DuoIcon)
/// kecuali sport/pet/sos yang tak punya padanan (tetap ledger).
/// Cabang SAMA PERSIS dengan [iconForCategory] plus wifi (sebelum tagihan)
/// dan tabungan/saving; income → Download, topup → Add, transfer → transfer.
/// [iconForCategory] lama dipertahankan untuk layar lain hingga migrasi T6.
String svgForCategory(String? category) {
  // Kategori baru (investasi, donasi, keluarga, olahraga, hewan, darurat)
  // dicek dulu; cabang lama di bawah tak berubah perilaku.
  final cool = coolForNewCategory(category);
  if (cool != null) return cool;
  final c = (category ?? '').toLowerCase();
  if (c.contains('makan') || c.contains('minum') || c.contains('jajan') || c.contains('kuliner')) {
    return 'assets/icons/coolicons/Coffee.svg';
  }
  if (c.contains('transport') || c.contains('bensin') || c.contains('parkir') || c.contains('ojek') || c.contains('tol')) {
    return 'assets/icons/coolicons/Car_Auto.svg';
  }
  if (c.contains('belanja')) return 'assets/icons/coolicons/Shopping_Cart_01.svg';
  if (c.contains('pulsa') || c.contains('internet') || c.contains('wifi')) {
    return 'assets/icons/coolicons/Wifi_High.svg';
  }
  if (c.contains('tagihan') || c.contains('listrik') || c.contains('air') || c.contains('internet') || c.contains('pulsa') || c.contains('kuota')) {
    return 'assets/icons/coolicons/File_Document.svg';
  }
  if (c.contains('sehat') || c.contains('obat') || c.contains('dokter')) {
    return 'assets/icons/coolicons/Heart_01.svg';
  }
  if (c.contains('pendidikan') ||
      c.contains('didik') ||
      c.contains('sekolah') ||
      c.contains('kuliah') ||
      c.contains('kursus') ||
      c.contains('buku')) {
    return 'assets/icons/coolicons/Book_Open.svg';
  }
  if (c.contains('hiburan') || c.contains('film') || c.contains('game') || c.contains('musik')) {
    return 'assets/icons/coolicons/Headphones.svg';
  }
  if (c.contains('tabungan') || c.contains('saving')) {
    return 'assets/icons/coolicons/Save.svg';
  }
  if (c.contains('gaji') || c.contains('upah') || c.contains('bonus')) {
    return 'assets/icons/coolicons/Download.svg';
  }
  if (c.contains('topup') || c.contains('top up') || c.contains('isi saldo')) {
    return 'assets/icons/coolicons/Add_Plus_Circle.svg';
  }
  if (c.contains('transfer')) return 'assets/icons/coolicons/Arrow_Left_Right.svg';
  return 'assets/icons/coolicons/Tag.svg';
}

/// SVG untuk kunci ikon hasil kustomisasi user (picker kategori).
/// Kunci di luar daftar dikenal jatuh ke Tag (tak pernah throw).
String svgForMetaIcon(String key) {
  switch (key) {
    case 'food':
      return 'assets/icons/coolicons/Coffee.svg';
    case 'transport':
      return 'assets/icons/coolicons/Car_Auto.svg';
    case 'shopping':
      return 'assets/icons/coolicons/Shopping_Cart_01.svg';
    case 'bills':
      return 'assets/icons/coolicons/File_Document.svg';
    case 'health':
      return 'assets/icons/coolicons/Heart_01.svg';
    case 'education':
      return 'assets/icons/coolicons/Book_Open.svg';
    case 'entertainment':
      return 'assets/icons/coolicons/Headphones.svg';
    case 'topup':
      return 'assets/icons/coolicons/Add_Plus_Circle.svg';
    case 'income':
      return 'assets/icons/coolicons/Download.svg';
    case 'wallet':
      return 'assets/icons/coolicons/Credit_Card_01.svg';
    case 'transfer':
      return 'assets/icons/coolicons/Arrow_Left_Right.svg';
    default:
      return 'assets/icons/coolicons/Tag.svg';
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
