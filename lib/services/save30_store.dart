// Simpanan tantangan hemat 30 hari (prefs saja, tanpa server).
// `save30_active` (JSON {start, target, celebrated}) +
// `save30_history` (stringList JSON, cap-12 seperti game_store).
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _kActive = 'save30_active';
const _kHistory = 'save30_history';
const save30HistoryCap = 12;

class Save30Active {
  final String startYmd;
  final double dailyTarget;
  final List<int> celebrated;
  const Save30Active({
    required this.startYmd,
    required this.dailyTarget,
    this.celebrated = const [],
  });

  Map<String, dynamic> toJson() => {
        'start': startYmd,
        'target': dailyTarget,
        'celebrated': celebrated,
      };

  static Save30Active? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final s = '${m['start'] ?? ''}';
      final t = (m['target'] as num?)?.toDouble();
      if (s.length < 10 || t == null || t <= 0) return null;
      return Save30Active(
        startYmd: s.substring(0, 10),
        dailyTarget: t,
        celebrated: [
          for (final e in (m['celebrated'] as List? ?? []))
            (e as num?)?.toInt(),
        ].whereType<int>().toList(),
      );
    } catch (_) {
      return null;
    }
  }
}

class Save30Entry {
  final String startYmd;
  final double target;
  final double spent;
  final int good;
  final bool success;
  const Save30Entry({
    required this.startYmd,
    required this.target,
    required this.spent,
    required this.good,
    required this.success,
  });

  Map<String, dynamic> toJson() => {
        'start': startYmd,
        'target': target,
        'spent': spent,
        'good': good,
        'success': success,
      };

  static Save30Entry? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    try {
      final m = Map<String, dynamic>.from(raw);
      final t = (m['target'] as num?)?.toDouble();
      if (t == null) return null;
      return Save30Entry(
        startYmd: '${m['start'] ?? ''}',
        target: t,
        spent: ((m['spent'] as num?) ?? 0).toDouble(),
        good: ((m['good'] as num?) ?? 0).toInt(),
        success: m['success'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

Future<Save30Active?> loadSave30Active() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return Save30Active.tryParse(prefs.getString(_kActive));
  } catch (_) {
    return null;
  }
}

Future<void> saveSave30Active(Save30Active? a) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (a == null) {
      await prefs.remove(_kActive);
    } else {
      await prefs.setString(_kActive, jsonEncode(a.toJson()));
    }
  } catch (_) {}
}

Future<List<Save30Entry>> loadSave30History() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kHistory) ?? [];
    final out = <Save30Entry>[];
    for (final s in raw) {
      try {
        final e = Save30Entry.tryParse(jsonDecode(s));
        if (e != null) out.add(e);
      } catch (_) {}
    }
    return out.take(save30HistoryCap).toList();
  } catch (_) {
    return [];
  }
}

Future<void> addSave30History(Save30Entry e) async {
  try {
    final cur = await loadSave30History();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kHistory,
      [for (final x in [e, ...cur].take(save30HistoryCap)) jsonEncode(x.toJson())],
    );
  } catch (_) {}
}
