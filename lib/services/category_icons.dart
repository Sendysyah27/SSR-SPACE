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
      return const Color(0xFF0D9488); // teal (ganti ungu)
    case 5:
      return const Color(0xFFE07B39); // oranye (ganti pink)
    case 6:
      return const Color(0xFF65A30D);
    case 8:
      return const Color(0xFF0891B2); // cyan
    case 9:
      return const Color(0xFF1F3C88); // navy
    case 10:
      return const Color(0xFFD9541E); // oranye tua
    case 11:
      return const Color(0xFF14957F); // hijau teal
    default:
      return const Color(0xFF64748B);
  }
}

/// Pasangan pastel (latar + ikon) per kategori ala mockup Batch 287:
/// kotak kategori pastel dengan ikon berwarna di tengah. Cabang kata
/// kunci mengikuti [iconForCategory]/[svgForCategory].
({Color bg, Color fg}) catPastelFor(String? category) {
  final c = (category ?? '').toLowerCase();
  if (c.contains('kopi')) {
    return (bg: const Color(0xFFFFE8D6), fg: const Color(0xFFB45F2D));
  }
  if (c.contains('makan') ||
      c.contains('minum') ||
      c.contains('jajan') ||
      c.contains('kuliner')) {
    return (bg: const Color(0xFFFFE3C2), fg: const Color(0xFFD97316));
  }
  if (c.contains('transport') ||
      c.contains('bensin') ||
      c.contains('parkir') ||
      c.contains('ojek') ||
      c.contains('tol')) {
    return (bg: const Color(0xFFD6E7FF), fg: const Color(0xFF2E6BE6));
  }
  if (c.contains('belanja')) {
    return (bg: const Color(0xFFFFD9E8), fg: const Color(0xFFC2437E));
  }
  if (c.contains('tagihan') ||
      c.contains('listrik') ||
      c.contains('air') ||
      c.contains('internet') ||
      c.contains('pulsa') ||
      c.contains('kuota')) {
    return (bg: const Color(0xFFE4DCFF), fg: const Color(0xFF6D4BD8));
  }
  if (c.contains('sehat') || c.contains('obat') || c.contains('dokter')) {
    return (bg: const Color(0xFFD9F5E9), fg: const Color(0xFF12805C));
  }
  if (c.contains('hiburan') ||
      c.contains('film') ||
      c.contains('game') ||
      c.contains('musik')) {
    return (bg: const Color(0xFFFFF0C2), fg: const Color(0xFFA87B0A));
  }
  if (c.contains('tabungan') || c.contains('saving')) {
    return (bg: const Color(0xFFCFF5DA), fg: const Color(0xFF1F7A4D));
  }
  return (bg: const Color(0xFFD6E7FF), fg: const Color(0xFF2E6BE6));
}
