import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Subkategori + meta warna/ikon per kategori (P2), logika murni + IO prefs.
///
/// Tanpa migration: subkategori disimpan sebagai bagian nilai `category`
/// (`Kategori > Sub`). Laporan dan budget grup di lapis kategori ([topOf])
/// agar angka tidak berubah. Peta warna/ikon di prefs `app_category_meta`.
const kSubSep = ' > ';

/// Urai nilai gabungan: 'Makan > Jajan' -> ('Makan', 'Jajan');
/// 'Makan' -> ('Makan', null). Sepihak: pemisah pertama yang dipakai.
({String top, String? sub}) parseCategory(String value) {
  final idx = value.indexOf('>');
  if (idx < 0) return (top: value.trim(), sub: null);
  final top = value.substring(0, idx).trim();
  final sub = value.substring(idx + 1).trim();
  return (top: top, sub: sub.isEmpty ? null : sub);
}

/// Gabung lapis: sub kosong -> top saja.
String formatCategory(String top, String? sub) {
  final s = (sub ?? '').trim();
  if (s.isEmpty) return top.trim();
  return '${top.trim()}$kSubSep$s';
}

/// False bila nama mengandung pemisah atau kosong (ditolak saat input).
bool isValidSubName(String name) {
  final t = name.trim();
  if (t.isEmpty) return false;
  return !t.contains('>');
}

/// Kunci grup laporan/budget: lapis atas, trim. Kosong -> '' (pemanggil
/// memetakan ke Lainnya).
String topOf(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  return parseCategory(value).top;
}

/// Meta per kategori: indeks palet 0-7 + kunci ikon AppIcons.
class CatMeta {
  final int color;
  final String icon;

  const CatMeta({required this.color, required this.icon});

  static const def = CatMeta(color: 7, icon: 'categoryFallback');

  Map<String, dynamic> toJson() => {'color': color, 'icon': icon};

  static CatMeta tryParse(dynamic raw) {
    if (raw is! Map) return def;
    final c = (raw['color'] as num?)?.toInt();
    final icon = raw['icon']?.toString() ?? '';
    if (c == null || c < 0 || c > 7 || icon.isEmpty || icon.length > 32) {
      return def;
    }
    return CatMeta(color: c, icon: icon);
  }
}

/// Bersihkan peta mentah: kunci trim non-kosong, nilai lewat [CatMeta.tryParse].
Map<String, CatMeta> sanitizeMeta(Map<String, dynamic> raw) {
  final out = <String, CatMeta>{};
  raw.forEach((k, v) {
    final t = k.trim();
    if (t.isEmpty || t.length > 40) return;
    out[t] = CatMeta.tryParse(v);
  });
  return out;
}

const _kMeta = 'app_category_meta';

Future<Map<String, CatMeta>> loadCategoryMeta() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kMeta);
  if (raw == null || raw.isEmpty) return {};
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return sanitizeMeta(map);
  } catch (_) {
    return {};
  }
}

Future<void> saveCategoryMeta(Map<String, CatMeta> meta) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _kMeta,
    jsonEncode({for (final e in meta.entries) e.key: e.value.toJson()}),
  );
}
