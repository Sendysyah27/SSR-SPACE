import 'package:ssr_space/utils/strings.dart';

String _fmt(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';

String currentMonth() {
  final n = DateTime.now();
  return _fmt(n.year, n.month);
}

/// Urai 'YYYY-MM' dengan toleran: format rusak (pendek, non-angka,
/// bulan di luar 1-12) jatuh ke bulan berjalan, bukan throw di build.
List<int> _parts(String m) {
  final y = m.length >= 4 ? int.tryParse(m.substring(0, 4)) : null;
  final mo = m.length >= 7 && m[4] == '-'
      ? int.tryParse(m.substring(5, 7))
      : null;
  if (y == null || mo == null || mo < 1 || mo > 12) {
    final n = DateTime.now();
    return [n.year, n.month];
  }
  return [y, mo];
}

String prevMonth(String m) {
  final p = _parts(m);
  if (p[1] == 1) return _fmt(p[0] - 1, 12);
  return _fmt(p[0], p[1] - 1);
}

String nextMonth(String m) {
  final p = _parts(m);
  if (p[1] == 12) return _fmt(p[0] + 1, 1);
  return _fmt(p[0], p[1] + 1);
}

String monthLabel(String m) {
  final p = _parts(m);
  final key = 'm${p[1].toString().padLeft(2, '0')}';
  return '${tr(key)} ${p[0]}';
}

String monthStart(String m) => '$m-01';
String monthEnd(String m) => '${nextMonth(m)}-01';
