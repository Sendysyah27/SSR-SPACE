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
