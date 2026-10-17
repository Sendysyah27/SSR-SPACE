import 'package:ssr_space/services/achievement_notify.dart';
import 'package:ssr_space/services/error_reporter.dart';
import 'package:ssr_space/services/game_badges.dart';
import 'package:ssr_space/services/supabase_config.dart';

/// Status gamifikasi dari server (migration_21 RPC `gamification_status`).
///
/// Server = sumber kebenaran lintas-device untuk streak, XP/level, dan 8
/// badge server-derivable. [stale] diisi pemanggil yang menyajikan hasil
/// hitung lokal sebagai ganti; selalu false untuk bacaan server segar.
class GamificationStatus {
  final int streakDays;
  final int streakBest;
  final int xp;
  final int level;
  final bool streakTodayDone;
  final bool streakGraceUsed;
  final Set<String> badges;
  final List<String> newBadges;
  final bool stale;

  const GamificationStatus({
    this.streakDays = 0,
    this.streakBest = 0,
    this.xp = 0,
    this.level = 0,
    this.streakTodayDone = false,
    this.streakGraceUsed = false,
    this.badges = const {},
    this.newBadges = const [],
    this.stale = false,
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

Set<String> _parseBadges(dynamic raw) {
  final out = <String>{};
  if (raw is List) {
    for (final e in raw) {
      final id = e is Map ? e['id'] : e;
      if (id is String && _knownBadgeIds.contains(id)) out.add(id);
    }
  }
  return out;
}

List<String> _parseNewBadges(dynamic raw) {
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
      streakBest: _asInt(map['streak_best']),
      xp: _asInt(map['xp']),
      level: _asInt(map['level']),
      streakTodayDone: _asBool(map['streak_today_done']),
      streakGraceUsed: _asBool(map['streak_grace_used']),
      badges: _parseBadges(map['badges']),
      newBadges: _parseNewBadges(map['new_badges']),
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

/// Satu-satunya hook notif pencapaian: badge baru -> tampilkan lalu ack
/// segera (panggilan berikutnya kosong, cegah dobel Beranda+Arcade).
Future<void> syncAchievements(GamificationStatus? s) async {
  final ids = s?.newBadges;
  if (ids == null || ids.isEmpty) return;
  await AchievementNotify.showNew(ids);
  await ackAchievements(ids);
}
