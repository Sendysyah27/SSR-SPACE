import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Simpanan gamifikasi (prefs saja, tanpa server):
/// `game_seen_badges` (list id), `game_challenges` (list JSON
/// {template, week, status} — status 0 jalan, 1 selesai, 2 gagal).
const _kSeen = 'game_seen_badges';
const _kChallenges = 'game_challenges';

Future<Set<String>> loadSeenBadges() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kSeen);
  if (raw == null || raw.isEmpty) return {};
  try {
    return (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
  } catch (_) {
    return {};
  }
}

Future<void> saveSeenBadges(Set<String> ids) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kSeen, jsonEncode(ids.toList()));
}

class StoredChallenge {
  final String template;
  final String week;
  final int status;
  const StoredChallenge({
    required this.template,
    required this.week,
    required this.status,
  });

  Map<String, dynamic> toJson() =>
      {'template': template, 'week': week, 'status': status};

  static StoredChallenge? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final t = raw['template']?.toString() ?? '';
    final w = raw['week']?.toString() ?? '';
    final s = (raw['status'] as num?)?.toInt();
    if (t.isEmpty || w.isEmpty || s == null || (s != 0 && s != 1 && s != 2)) {
      return null;
    }
    return StoredChallenge(template: t, week: w, status: s);
  }
}

Future<List<StoredChallenge>> loadChallenges() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kChallenges);
  if (raw == null || raw.isEmpty) return [];
  try {
    return [
      for (final e in jsonDecode(raw) as List) StoredChallenge.tryParse(e),
    ].whereType<StoredChallenge>().take(12).toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveChallenges(List<StoredChallenge> items) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _kChallenges,
    jsonEncode([for (final c in items.take(12)) c.toJson()]),
  );
}
