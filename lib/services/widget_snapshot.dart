/// Snapshot widget hari ini (P2 widget-qs-tile), Dart murni.
///
/// Provider native tidak memegang token Supabase dan tidak query langsung:
/// app menulis satu snapshot JSON ke prefs `widget_snapshot`, provider
/// hanya membaca string itu. Format: {date, text, text2, masked}.
/// `text2` opsional (kompatibel snapshot lama): baris kedua widget
/// (sisa budget), kosong berarti provider menyembunyikan baris itu.
String formatSnapshot({
  required String date,
  required String text,
  String text2 = '',
  required bool masked,
}) =>
    '{"date":"$date","text":"${_esc(text)}",'
    '"text2":"${_esc(text2)}","masked":${masked ? 1 : 0}}';

/// Kunci prefs snapshot per widget (satu kunci per widget, fase 2).
/// `widget_snapshot` (Hari-ini) TAK DIUBAH (milik today_widget.dart,
/// provider lama kompatibel). Ketiga kunci memakai format JSON yang sama
/// ({date, text, text2, masked}) via formatSnapshot/parseSnapshot.
const widgetBudgetSnapshotKey = 'widget_snapshot_budget';
const widgetBalanceSnapshotKey = 'widget_snapshot_balance';

/// Lampu status budget widget (murni, tanpa Flutter).
///
/// 'danger' bila total sisa negatif ATAU ada kategori jebol (belanja >
/// limit); selain itu 'safe'. Penulis memetakan ke copy pakai-ulang
/// pace_danger/pace_safe (tanpa kunci strings baru).
/// Tanpa tier waspada: proyeksi pace butuh laju harian (follow-up).
String widgetBudgetLamp({required double left, required bool anyOver}) =>
    (left < 0 || anyOver) ? 'danger' : 'safe';

String _esc(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll('\n', ' ');

class TodaySnapshot {
  final String date;
  final String text;
  final String text2;
  final bool masked;

  const TodaySnapshot({
    required this.date,
    required this.text,
    this.text2 = '',
    required this.masked,
  });
}

/// Parse toleran: rusak/hilang -> null (provider tampilkan ajakan buka app).
/// Snapshot lama tanpa text2 terbaca dengan text2 kosong.
TodaySnapshot? parseSnapshot(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final date = _strField(raw, 'date');
    final text = _strField(raw, 'text');
    if (date == null || text == null) return null;
    final masked = RegExp(r'"masked"\s*:\s*1').hasMatch(raw);
    return TodaySnapshot(
      date: date,
      text: text,
      text2: _strField(raw, 'text2') ?? '',
      masked: masked,
    );
  } catch (_) {
    return null;
  }
}

String? _strField(String raw, String key) {
  final m = RegExp('"$key"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"').firstMatch(raw);
  if (m == null) return null;
  return m.group(1)!.replaceAll('\\"', '"').replaceAll('\\\\', '\\');
}

/// Sisa budget bulan ini: jumlah limit kurang belanja per kategori
/// (boleh negatif bila jebol, ditampilkan apa adanya).
double widgetBudgetLeft(
  Map<String, double> limitByCat,
  Map<String, double> spentByCat,
) {
  var left = 0.0;
  for (final e in limitByCat.entries) {
    left += e.value - (spentByCat[e.key] ?? 0);
  }
  return left;
}
