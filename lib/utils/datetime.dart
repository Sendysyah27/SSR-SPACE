const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String dayLabel(String? ymd) {
  if (ymd == null || ymd.length < 10) return '-';
  final m = int.tryParse(ymd.substring(5, 7)) ?? 0;
  if (m < 1 || m > 12) return ymd;
  return '${ymd.substring(8, 10)} ${_shortMonths[m - 1]} ${ymd.substring(0, 4)}';
}

String txTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}
