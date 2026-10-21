import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ai_draft.dart';

/// Satu draft scan struk yang disimpan user (batch 286 tahap C).
class ScanDraftEntry {
  final String id;
  final DateTime savedAt;
  final AiDraft draft;
  const ScanDraftEntry({
    required this.id,
    required this.savedAt,
    required this.draft,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'savedAt': savedAt.toIso8601String(),
        'draft': draft.toJson(),
      };

  /// Fail-open: entri rusak -> null (dilewati, bukan crash).
  static ScanDraftEntry? fromJson(dynamic v) {
    try {
      if (v is! Map) return null;
      final m = Map<String, dynamic>.from(v);
      final id = m['id'];
      final at = DateTime.tryParse('${m['savedAt']}');
      final dj = m['draft'];
      if (id is! String || id.isEmpty || at == null || dj is! Map) {
        return null;
      }
      return ScanDraftEntry(
        id: id,
        savedAt: at,
        draft: AiDraft.fromJson(Map<String, dynamic>.from(dj)),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Penyimpanan lokal draft scan (SharedPreferences, pola org_prefs).
///
/// Draft TIDAK kedaluwarsa otomatis: user yang memutuskan memakai,
/// mengedit ulang, atau membuangnya dari daftar draft di menu scan.
class ScanDraftStore {
  static const _key = 'scan_drafts_v1';

  Future<List<ScanDraftEntry>> list() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <ScanDraftEntry>[];
      for (final v in decoded) {
        final e = ScanDraftEntry.fromJson(v);
        if (e != null) out.add(e);
      }
      out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _write(List<ScanDraftEntry> entries) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _key,
      jsonEncode([for (final e in entries) e.toJson()]),
    );
  }

  /// Simpan draft baru; mengembalikan entri (dengan id) yang tersimpan.
  Future<ScanDraftEntry> add(AiDraft draft) async {
    final now = DateTime.now();
    final entry = ScanDraftEntry(
      id: 'sd${now.microsecondsSinceEpoch}',
      savedAt: now,
      draft: draft,
    );
    final entries = await list();
    entries.insert(0, entry);
    await _write(entries);
    return entry;
  }

  /// Timpa isi draft yang sudah ada (savedAt diperbarui).
  Future<void> update(String id, AiDraft draft) async {
    final entries = await list();
    final i = entries.indexWhere((e) => e.id == id);
    if (i < 0) return;
    entries[i] = ScanDraftEntry(id: id, savedAt: DateTime.now(), draft: draft);
    await _write(entries);
  }

  Future<void> remove(String id) async {
    final entries = await list();
    entries.removeWhere((e) => e.id == id);
    await _write(entries);
  }
}
