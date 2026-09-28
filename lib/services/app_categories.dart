import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kCategories = 'app_categories';

/// 10 kategori bawaan (disepakati user 2026-09-26, bisa diubah di Lainnya).
const kDefaultCategories = <String>[
  'Makanan',
  'Transportasi',
  'Belanja',
  'Tagihan',
  'Kesehatan',
  'Pendidikan',
  'Hiburan',
  'Pulsa & Internet',
  'Tabungan',
  'Lainnya',
];

/// Daftar kategori aktif: dipakai form catat dan saran.
/// Diisi di main() sebelum runApp; layar kategori mengubah + simpan.
final appCategories = ValueNotifier<List<String>>([...kDefaultCategories]);

/// Bersihkan daftar mentah: trim, buang kosong, dedupe (tak sensitif
/// huruf), batasi 20. Kosong → kembali ke bawaan. Murni, bisa di-test.
List<String> sanitizeCategories(List<String> raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final c in raw) {
    final t = c.trim();
    if (t.isEmpty) continue;
    final key = t.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    out.add(t);
    if (out.length >= 20) break;
  }
  return out.isEmpty ? [...kDefaultCategories] : out;
}

Future<void> loadAppCategories(SharedPreferences prefs) async {
  final raw = prefs.getStringList(_kCategories);
  appCategories.value = raw == null
      ? [...kDefaultCategories]
      : sanitizeCategories(raw);
}

Future<void> saveAppCategories(List<String> cats) async {
  final clean = sanitizeCategories(cats);
  appCategories.value = clean;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_kCategories, clean);
}
