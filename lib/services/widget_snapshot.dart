/// Snapshot widget hari ini (P2 widget-qs-tile), Dart murni.
///
/// Provider native tidak memegang token Supabase dan tidak query langsung:
/// app menulis satu snapshot JSON ke prefs `widget_snapshot`, provider
/// hanya membaca string itu. Format: {date, text, masked}.
String formatSnapshot({
  required String date,
  required String text,
  required bool masked,
}) =>
    '{"date":"$date","text":"${_esc(text)}","masked":${masked ? 1 : 0}}';

String _esc(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll('\n', ' ');

class TodaySnapshot {
  final String date;
  final String text;
  final bool masked;

  const TodaySnapshot({
    required this.date,
    required this.text,
    required this.masked,
  });
}

/// Parse toleran: rusak/hilang -> null (provider tampilkan ajakan buka app).
TodaySnapshot? parseSnapshot(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final date = _strField(raw, 'date');
    final text = _strField(raw, 'text');
    if (date == null || text == null) return null;
    final masked = RegExp(r'"masked"\s*:\s*1').hasMatch(raw);
    return TodaySnapshot(date: date, text: text, masked: masked);
  } catch (_) {
    return null;
  }
}

String? _strField(String raw, String key) {
  final m = RegExp('"$key"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"').firstMatch(raw);
  if (m == null) return null;
  return m.group(1)!.replaceAll('\\"', '"').replaceAll('\\\\', '\\');
}
