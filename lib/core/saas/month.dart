const _months = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String _fmt(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';

String currentMonth() {
  final n = DateTime.now();
  return _fmt(n.year, n.month);
}

List<int> _parts(String m) => [int.parse(m.substring(0, 4)), int.parse(m.substring(5, 7))];

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
  return '${_months[p[1] - 1]} ${p[0]}';
}

String monthStart(String m) => '$m-01';
String monthEnd(String m) => '${nextMonth(m)}-01';
