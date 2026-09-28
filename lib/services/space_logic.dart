// Logika murni We Space (tanpa flutter/supabase) — bisa diuji `dart` lokal.

/// Parse mode dari kolom `organizations.space_mode`. Fail-open: apapun yang
/// bukan 'bendahara' persis → 'bebas' (perilaku lama, data tetap terlihat).
String parseSpaceMode(dynamic raw) =>
    raw is String && raw == 'bendahara' ? 'bendahara' : 'bebas';

/// Key prefs penanda "terakhir lihat aktivitas" per workspace.
String spaceSeenKey(String orgId) => 'space_seen_$orgId';

/// Hitung log yang lebih baru dari [seen]. seen null = semua belum dibaca.
int unseenCount(List<DateTime> logTimes, DateTime? seen) {
  if (seen == null) return logTimes.length;
  var n = 0;
  for (final t in logTimes) {
    if (t.isAfter(seen)) n++;
  }
  return n;
}

/// Identitas pencatat tanpa nama/email (privasi ikut `list_org_members`).
/// Return (potonganId, apakahSaya). UI menyusun label via tr()
/// (`sp_by_you` / `sp_by_member`). Actor null/pendek → '????'.
(String, bool) actorLabel(String? actorId, String myId) {
  if (actorId != null && actorId == myId) return ('', true);
  final short = (actorId != null && actorId.length >= 4)
      ? actorId.substring(0, 4)
      : '????';
  return (short, false);
}
