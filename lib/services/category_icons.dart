import 'package:flutter/material.dart';

IconData iconForCategory(String? category) {
  final c = (category ?? '').toLowerCase();
  if (c.contains('makan') || c.contains('minum') || c.contains('jajan') || c.contains('kuliner')) {
    return Icons.restaurant_outlined;
  }
  if (c.contains('transport') || c.contains('bensin') || c.contains('parkir') || c.contains('ojek') || c.contains('tol')) {
    return Icons.directions_car_outlined;
  }
  if (c.contains('belanja')) return Icons.shopping_bag_outlined;
  if (c.contains('tagihan') || c.contains('listrik') || c.contains('air') || c.contains('internet') || c.contains('pulsa') || c.contains('kuota')) {
    return Icons.receipt_long_outlined;
  }
  if (c.contains('sehat') || c.contains('obat') || c.contains('dokter')) {
    return Icons.favorite_outline;
  }
  if (c.contains('sekolah') || c.contains('kuliah') || c.contains('kursus') || c.contains('buku')) {
    return Icons.school_outlined;
  }
  if (c.contains('hiburan') || c.contains('film') || c.contains('game') || c.contains('musik')) {
    return Icons.movie_outlined;
  }
  if (c.contains('gaji') || c.contains('upah') || c.contains('bonus')) {
    return Icons.payments_outlined;
  }
  if (c.contains('topup') || c.contains('top up') || c.contains('isi saldo')) {
    return Icons.add_card_outlined;
  }
  if (c.contains('transfer')) return Icons.swap_horiz_outlined;
  return Icons.category_outlined;
}
