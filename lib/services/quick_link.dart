import 'package:shared_preferences/shared_preferences.dart';

/// Deep-link quick-entry + antrean satu-slot (Fase 2 widget, spec §4.2).
///
/// Skema custom `ssrspace`, host `quick-entry`, query `type=out|in|transfer`.
/// Konsumsi hanya bila sesi siap ([quickLinkReady]); selain itu antre di
/// prefs agar dibuka lagi saat kondisi siap (jujur, bukan gagal diam-diam).

/// Skema + host deep-link (exact, sinkron dengan intent-filter native).
const quickEntryScheme = 'ssrspace';
const quickEntryHost = 'quick-entry';

/// Prefs key antrean satu-slot, format `{"type":"out","at":<ms epoch>}`.
const pendingQuickEntryKey = 'pending_quick_entry';

/// Kedaluwarsa antrean: sheet kemarin jangan dibuka hari ini.
const quickEntryTtl = Duration(hours: 24);

const _quickEntryTypes = <String>{'out', 'in', 'transfer'};

/// Parse deep-link → `out|in|transfer`, atau null bila bukan link kita.
/// Tipe absen/kosong/asing → `out` (default catat keluar, jangan crash).
/// Skema/host salah atau uri null → null (abaikan, bukan untuk kita).
String? parseQuickLink(Uri? uri) {
  if (uri == null) return null;
  if (uri.scheme != quickEntryScheme || uri.host != quickEntryHost) {
    return null;
  }
  final t = uri.queryParameters['type'];
  if (t == null || t.isEmpty || !_quickEntryTypes.contains(t)) return 'out';
  return t;
}

/// Antre tipe untuk dibuka nanti (timpa slot lama, satu-slot).
/// Tipe asing disanitasi ke `out` (fail-safe, tak pernah simpan sampah).
Future<void> queuePending(String type) async {
  final t = _quickEntryTypes.contains(type) ? type : 'out';
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    pendingQuickEntryKey,
    '{"type":"$t","at":${DateTime.now().millisecondsSinceEpoch}}',
  );
}

/// Ambil antrean sekali pakai: baca + hapus atomik di mata pemanggil.
/// Basi (>24 jam), kosong, atau rusak → null (basi/rusak ikut dibuang).
/// Tipe tersimpan di luar `out|in|transfer` → null (fail-closed).
Future<String?> takePending() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(pendingQuickEntryKey);
  await prefs.remove(pendingQuickEntryKey);
  if (raw == null || raw.isEmpty) return null;
  final type = RegExp(r'"type"\s*:\s*"([^"]*)"').firstMatch(raw)?.group(1);
  final atMs = int.tryParse(
    RegExp(r'"at"\s*:\s*(\d+)').firstMatch(raw)?.group(1) ?? '',
  );
  if (type == null || atMs == null) return null;
  if (!_quickEntryTypes.contains(type)) return null;
  final ageMs = DateTime.now().millisecondsSinceEpoch - atMs;
  if (ageMs > quickEntryTtl.inMilliseconds) return null;
  return type;
}

/// Gate konsumsi: true hanya bila login + workspace ada + PIN tak terkunci.
bool quickLinkReady({
  required bool loggedIn,
  required bool hasOrg,
  required bool locked,
}) =>
    loggedIn && hasOrg && !locked;
