/// Perbandingan bulan ini vs bulan lalu per kategori. Dart murni.
///
/// Urut berdasar |selisih| terbesar. Persen null = kategori baru bulan
/// ini (pembagi nol). Pemanggil memberi map yang sudah difilter sama
/// (mis. ikut filter dompet) supaya apel lawan apel.
class MonthDelta {
  final String category;
  final double cur;
  final double prev;
  final double delta;
  final double? pct;
  const MonthDelta({
    required this.category,
    required this.cur,
    required this.prev,
    required this.delta,
    required this.pct,
  });
}

List<MonthDelta> compareMonths(
  Map<String, double> cur,
  Map<String, double> prev,
) {
  final out = <MonthDelta>[];
  final keys = <String>{...cur.keys, ...prev.keys};
  for (final k in keys) {
    final c = cur[k] ?? 0;
    final p = prev[k] ?? 0;
    if (c <= 0 && p <= 0) continue;
    out.add(MonthDelta(
      category: k,
      cur: c,
      prev: p,
      delta: c - p,
      pct: p > 0 ? (c - p) / p * 100 : null,
    ));
  }
  out.sort((a, b) => b.delta.abs().compareTo(a.delta.abs()));
  return out;
}
