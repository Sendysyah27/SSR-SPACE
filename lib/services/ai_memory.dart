import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'ai_soul.dart';

// Memori AI Chat: daftar fakta singkat user (maks 20, FIFO).
// Ditulis otomatis dari blok ```ingat``` balasan AI; user bisa hapus
// per item dari layar chat. Tanpa login = tetap lokal per HP.
const _kAiMemory = 'ai_memory_facts';

Future<List<String>> loadAiMemory() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kAiMemory);
    if (raw == null || raw.isEmpty) return [];
    final d = jsonDecode(raw);
    if (d is! List) return [];
    return [
      for (final e in d.take(aiMemoryCap))
        if (e is String && e.trim().isNotEmpty) e.trim()
    ];
  } catch (_) {
    return [];
  }
}

Future<void> addAiMemory(Iterable<String> facts) async {
  try {
    final cur = await loadAiMemory();
    for (final f in facts) {
      final t = f.trim();
      if (t.isEmpty || cur.contains(t)) continue;
      cur.add(t);
    }
    while (cur.length > aiMemoryCap) {
      cur.removeAt(0);
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAiMemory, jsonEncode(cur));
  } catch (_) {}
}

Future<void> removeAiMemory(String fact) async {
  try {
    final cur = await loadAiMemory();
    cur.remove(fact);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAiMemory, jsonEncode(cur));
  } catch (_) {}
}

Future<void> clearAiMemory() async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kAiMemory);
  } catch (_) {}
}
