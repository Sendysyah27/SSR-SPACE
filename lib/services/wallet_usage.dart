import 'dart:convert';

const walletUsageCap = 50;
const _maxHit = 9999;

/// Catat satu pemakaian manual. Id kosong diabaikan.
/// Bila penuh, buang entri hitung terkecil (id terlama dulu).
Map<String, int> recordUse(Map<String, int> counts, String id) {
  if (id.isEmpty) return Map<String, int>.of(counts);
  final out = Map<String, int>.of(counts);
  out[id] = ((out[id] ?? 0) + 1).clamp(1, _maxHit);
  if (out.length <= walletUsageCap) return out;
  final entries = out.entries.toList();
  final order = <String, int>{for (var i = 0; i < entries.length; i++) entries[i].key: i};
  entries.sort((a, b) {
    final byHit = a.value.compareTo(b.value);
    if (byHit != 0) return byHit;
    return order[a.key]!.compareTo(order[b.key]!);
  });
  out.remove(entries.first.key);
  return out;
}

/// Urutkan id dompet: hitung DESC, seri ikut nama ASC, tanpa hitung ikut abjad di belakang.
List<String> sortIdsByUse(Map<String, int> counts, Map<String, String> names) {
  final ids = names.keys.toList()
    ..sort((a, b) {
      final byHit = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      if (byHit != 0) return byHit;
      return (names[a] ?? a).compareTo(names[b] ?? b);
    });
  return ids;
}

String encodeUsage(Map<String, int> counts) => jsonEncode(counts);

Map<String, int> decodeUsage(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    final d = jsonDecode(raw) as Map<String, dynamic>;
    final out = <String, int>{};
    d.forEach((k, v) {
      if (v is int && v > 0) out[k] = v.clamp(1, _maxHit);
      if (v is double && v > 0) out[k] = v.toInt().clamp(1, _maxHit);
    });
    return out;
  } catch (_) {
    return {};
  }
}
