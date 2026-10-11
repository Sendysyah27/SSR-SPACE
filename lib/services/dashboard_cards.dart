// Registri kartu dashboard Beranda: urutan + sembunyi + lampu budget.
// Murni Dart (tanpa Flutter). Order disimpan di prefs `dashboard_order`
// via stringList, hidden di `dashboard_hidden` (pola reports_section_order).

/// Id kartu yang dikenal, sekaligus urutan default.
const kDashboardDefault = ['budget', 'fitur', 'utang', 'allowance', 'networth'];

/// Parse toleran: rusak/kosong/asing jatuh ke default (fail-open).
/// Id default yang belum ada di simpanan lama dilengkapi di belakang
/// (kartu baru otomatis tampil; hidden tetap dihormati pemanggil).
List<String> parseDashboardOrder(dynamic raw) {
  if (raw is! List) return List.of(kDashboardDefault);
  final out = <String>[];
  for (final e in raw) {
    final v = e?.toString() ?? '';
    if (kDashboardDefault.contains(v) && !out.contains(v)) out.add(v);
  }
  for (final id in kDashboardDefault) {
    if (!out.contains(id)) out.add(id);
  }
  return out;
}

/// Geser kartu [id] sejauh [dir] (-1 naik, +1 turun), jepit di batas.
/// Id asing = tanpa perubahan.
List<String> moveDashboardCard(List<String> order, String id, int dir) {
  final i = order.indexOf(id);
  if (i < 0) return List.of(order);
  final j = (i + dir).clamp(0, order.length - 1);
  if (j == i) return List.of(order);
  final out = List.of(order);
  out[i] = out[j];
  out[j] = id;
  return out;
}

/// True bila kartu [id] disembunyikan.
bool isDashboardHidden(Set<String> hidden, String id) => hidden.contains(id);

/// Lampu traffic-light: hijau di bawah warnPct, emas sampai jebol,
/// merah saat >= 100%. Limit <= 0 = hijau (tak ada pagu).
String budgetLight({
  required double spent,
  required double limit,
  required int warnPct,
}) {
  if (limit <= 0) return 'green';
  final pct = spent / limit * 100;
  if (pct >= 100) return 'red';
  if (pct >= warnPct) return 'gold';
  return 'green';
}
