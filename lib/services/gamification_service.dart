import 'package:ssr_space/services/achievement_notify.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/game_badges.dart';
import 'package:ssr_space/services/game_store.dart';
import 'package:ssr_space/services/supabase_config.dart';

/// Status gamifikasi dari server (migration_21 RPC `gamification_status`).
///
/// Server = sumber kebenaran lintas-device untuk streak, XP/level, dan 8
/// badge server-derivable. Pemanggil fallback ke hitungan lokal jujur
/// (`fallbackXp` di `game_badges.dart`) saat RPC tak tersedia.
class GamificationStatus {
  final int streakDays;
  final int xp;
  final int level;
  final bool streakTodayDone;
  final bool streakGraceUsed;
  final Set<String> badges;
  final List<String> newBadges;

  const GamificationStatus({
    this.streakDays = 0,
    this.xp = 0,
    this.level = 0,
    this.streakTodayDone = false,
    this.streakGraceUsed = false,
    this.badges = const {},
    this.newBadges = const [],
  });
}

/// Id badge yang dikenal klien (server + lokal, Task 3). Id asing dari
/// server diabaikan agar UI tak membaca kunci `b_<id>_*` yang kosong.
final Set<String> _knownBadgeIds = {for (final b in allBadges) b.id};

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

bool _asBool(dynamic v) => v == true;

/// Parse daftar `badges` RPC (objek `{id, unlocked_at}` atau string id)
/// menjadi set id yang dikenal klien. Terlihat untuk unit test.
Set<String> parseBadgeSet(dynamic raw) {
  final out = <String>{};
  if (raw is List) {
    for (final e in raw) {
      final id = e is Map ? e['id'] : e;
      if (id is String && _knownBadgeIds.contains(id)) out.add(id);
    }
  }
  return out;
}

/// Parse `new_badges` RPC (list id) — buang id asing & duplikat. Terlihat
/// untuk unit test.
List<String> parseNewBadgeList(dynamic raw) {
  final out = <String>[];
  if (raw is List) {
    for (final e in raw) {
      if (e is String && _knownBadgeIds.contains(e) && !out.contains(e)) {
        out.add(e);
      }
    }
  }
  return out;
}

/// Baca status dari server. Selalu `null` saat gagal (RPC belum ada,
/// offline, atau error apa pun) — pemanggil fallback hitung lokal.
Future<GamificationStatus?> fetchGamification(String orgId) async {
  try {
    final res = await SupabaseConfig.client.rpc(
      'gamification_status',
      params: {'p_org_id': orgId},
    );
    final map = Map<String, dynamic>.from(res as Map);
    return GamificationStatus(
      streakDays: _asInt(map['streak_days']),
      xp: _asInt(map['xp']),
      level: _asInt(map['level']),
      streakTodayDone: _asBool(map['streak_today_done']),
      streakGraceUsed: _asBool(map['streak_grace_used']),
      badges: parseBadgeSet(map['badges']),
      newBadges: parseNewBadgeList(map['new_badges']),
    );
  } catch (_) {
    return null;
  }
}

/// Tandai badge sudah dinotifikasi (dedupe lintas-device). Fail-silent:
/// gagal = capture ke ErrorReporter, tidak pernah lempar.
Future<void> ackAchievements(List<String> ids) async {
  if (ids.isEmpty) return;
  try {
    await SupabaseConfig.client.rpc(
      'ack_achievements',
      params: {'p_ids': ids},
    );
  } catch (err, st) {
    await ErrorReporter.capture(err, st, context: 'ack_achievements');
  }
}

/// Sinkronisasi notifikasi pencapaian. Dipisah sebagai kelas yang bisa
/// disuntik (test seam) — produksi memakai [AchievementNotify.showNew],
/// [ackAchievements], dan [loadSeenBadges].
///
/// Aturan: tampilkan tiap badge baru SEKALI per device (dibanding
/// `seen` prefs + set sesi), lalu `ack` SEMUA id yang dilaporkan server
/// (termasuk yang dilewati) supaya tak memicu ulang. Panggilan beruntun
/// diserialkan agar Beranda+Arcade tak notif dobel dalam satu device.
class AchievementSync {
  final Future<void> Function(List<String> ids) show;
  final Future<void> Function(List<String> ids) ack;
  final Future<Set<String>> Function() loadSeen;

  final Set<String> _notifiedThisSession = <String>{};
  Future<void>? _inflight;

  AchievementSync({
    required this.show,
    required this.ack,
    required this.loadSeen,
  });

  /// [incoming] = `new_badges` server. Idempoten: aman dipanggil overlap.
  Future<void> sync(List<String>? incoming) async {
    if (incoming == null || incoming.isEmpty) return;
    final prev = _inflight;
    if (prev != null) {
      try {
        await prev;
      } catch (_) {}
    }
    final run = _run(incoming);
    _inflight = run;
    try {
      await run;
    } finally {
      if (identical(_inflight, run)) _inflight = null;
    }
  }

  Future<void> _run(List<String> incoming) async {
    Set<String> seen;
    try {
      seen = await loadSeen();
    } catch (_) {
      seen = <String>{};
    }
    final fresh = <String>[];
    for (final id in incoming) {
      if (seen.contains(id)) continue;
      if (!_notifiedThisSession.add(id)) continue;
      fresh.add(id);
    }
    if (fresh.isNotEmpty) await show(fresh);
    await ack(incoming);
  }
}

final AchievementSync _achievementSync = AchievementSync(
  show: AchievementNotify.showNew,
  ack: ackAchievements,
  loadSeen: loadSeenBadges,
);

/// Satu-satunya hook notif pencapaian: badge baru -> tampilkan yang belum
/// pernah dilihat, lalu ack semua agar panggilan berikutnya kosong.
Future<void> syncAchievements(GamificationStatus? s) =>
    _achievementSync.sync(s?.newBadges);
