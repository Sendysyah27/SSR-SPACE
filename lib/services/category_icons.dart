import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_icons.dart';

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
