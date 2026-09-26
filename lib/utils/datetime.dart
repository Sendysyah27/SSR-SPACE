import 'package:ssr_space/utils/strings.dart';

String dayLabel(String? ymd) {
  if (ymd == null || ymd.length < 10) return '-';
  final m = int.tryParse(ymd.substring(5, 7)) ?? 0;
  if (m < 1 || m > 12) return ymd;
  final key = 's${m.toString().padLeft(2, '0')}';
  return '${ymd.substring(8, 10)} ${tr(key)} ${ymd.substring(0, 4)}';
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

/// Label waktu satu baris untuk baris transaksi: "26 Sep 2026 • 12:04".
/// Tanggal saja bila jam tak ada; '' bila tak ada data sama sekali.
String txWhenLabel(String? ymd, String? iso) {
  final hasDate = ymd != null && ymd.length >= 10;
  final t = txTime(iso);
  if (!hasDate) return t;
  final d = dayLabel(ymd);
  return t.isEmpty ? d : '$d • $t';
}
