import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/utils/org_prefs.dart';

// Event koreksi kartu konfirmasi AI (batch 281D tahap 1, pola
// quick_record_correction_events Ollo): setiap user mengubah field
// hasil AI (tipe/jumlah/dompet/kategori/catatan) di form konfirmasi
// sebelum menyetujui, selisihnya disimpan verbatim sebagai bahan
// belajar. Lokal dulu (SharedPreferences), sinkron best-effort ke
// tabel ai_correction_events (migration_28). Semua jalur fail-open:
// tak pernah menghalangi simpan transaksi / bubble sukses.

const _kCorrectionEvents = 'ai_correction_events';

/// Batas simpan lokal; terlama dibuang lebih dulu.
const correctionEventCap = 200;

/// Urutan kunci yang dibandingkan & dilaporkan di [CorrectionEvent.changed].
const correctionFields = ['type', 'amount', 'wallet', 'category', 'note'];

class CorrectionEvent {
  final String id;
  final String ts;
  final String source;
  final Map<String, dynamic> ai;
  final Map<String, dynamic> fin;
  final List<String> changed;
  final bool synced;

  const CorrectionEvent({
    required this.id,
    required this.ts,
    required this.source,
    required this.ai,
    required this.fin,
    required this.changed,
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ts': ts,
        'source': source,
        'ai': ai,
        'fin': fin,
        'changed': changed,
        'synced': synced,
      };

  /// Payload untuk kolom jsonb server (tanpa status sinkron lokal).
  Map<String, dynamic> toPayload() {
    final m = toJson();
    m.remove('synced');
    return m;
  }

  CorrectionEvent markSynced() => CorrectionEvent(
        id: id,
        ts: ts,
        source: source,
        ai: ai,
        fin: fin,
        changed: changed,
        synced: true,
      );

  factory CorrectionEvent.fromJson(Map<String, dynamic> m) {
    Map<String, dynamic> asMap(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    return CorrectionEvent(
      id: (m['id'] ?? '').toString(),
      ts: (m['ts'] ?? '').toString(),
      source: (m['source'] ?? '').toString(),
      ai: asMap(m['ai']),
      fin: asMap(m['fin']),
      changed: [
        for (final e in (m['changed'] is List ? m['changed'] as List : []))
          e.toString(),
      ],
      synced: m['synced'] == true,
    );
  }
}

String _normStr(dynamic v) => v is String ? v.trim().toLowerCase() : '';

bool _amountDiff(dynamic a, dynamic b) {
  double? numOf(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.trim());
  final x = numOf(a);
  final y = numOf(b);
  if (x == null && y == null) return false;
  if (x == null || y == null) return true;
  return (x - y).abs() > 0.5;
}

/// Bangun event koreksi dari nilai AI vs nilai final user. MURNI.
/// Null bila tidak ada field yang berubah. Perbandingan string:
/// trim + case-insensitive; null dan '' dianggap sama. Nilai yang
/// disimpan di event = nilai apa adanya (bukan hasil normalisasi).
CorrectionEvent? buildCorrectionEvent({
  required Map<String, dynamic> ai,
  required Map<String, dynamic> fin,
  required String sourceText,
  DateTime? now,
}) {
  final changed = <String>[];
  for (final k in correctionFields) {
    final diff = k == 'amount'
        ? _amountDiff(ai[k], fin[k])
        : _normStr(ai[k]) != _normStr(fin[k]);
    if (diff) changed.add(k);
  }
  if (changed.isEmpty) return null;
  final t = now ?? DateTime.now();
  final src = sourceText.length <= 300
      ? sourceText
      : sourceText.substring(0, 300);
  return CorrectionEvent(
    id: 'ce${t.microsecondsSinceEpoch}',
    ts: t.toIso8601String(),
    source: src,
    ai: Map<String, dynamic>.of(ai),
    fin: Map<String, dynamic>.of(fin),
    changed: changed,
  );
}

Future<List<CorrectionEvent>> loadCorrectionEvents() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kCorrectionEvents);
    if (raw == null || raw.isEmpty) return [];
    final d = jsonDecode(raw);
    if (d is! List) return [];
    return [
      for (final e in d)
        if (e is Map) CorrectionEvent.fromJson(Map<String, dynamic>.from(e)),
    ];
  } catch (_) {
    return [];
  }
}

Future<void> _saveCorrectionEvents(List<CorrectionEvent> items) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(
    _kCorrectionEvents,
    jsonEncode([for (final e in items) e.toJson()]),
  );
}

/// Tambahkan satu event ke store lokal (cap [correctionEventCap]).
Future<void> recordCorrectionEvent(CorrectionEvent e) async {
  try {
    final cur = await loadCorrectionEvents();
    cur.add(e);
    while (cur.length > correctionEventCap) {
      cur.removeAt(0);
    }
    await _saveCorrectionEvents(cur);
  } catch (_) {}
}

Future<List<CorrectionEvent>> pendingCorrectionEvents() async => [
      for (final e in await loadCorrectionEvents())
        if (!e.synced) e,
    ];

/// Sinkron best-effort event pending ke tabel ai_correction_events.
/// Return jumlah yang berhasil terkirim. Gagal (offline / belum login /
/// migration belum jalan) -> 0 dan event tetap pending. Tak pernah throw.
Future<int> syncCorrectionEvents() async {
  try {
    final client = SupabaseConfig.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return 0;
    final orgId = await activeOrgId();
    if (orgId.isEmpty) return 0;
    final pending = await pendingCorrectionEvents();
    if (pending.isEmpty) return 0;
    await client.from('ai_correction_events').insert([
      for (final e in pending)
        {'org_id': orgId, 'user_id': uid, 'payload': e.toPayload()},
    ]);
    final all = await loadCorrectionEvents();
    final sentIds = {for (final e in pending) e.id};
    await _saveCorrectionEvents([
      for (final e in all) sentIds.contains(e.id) ? e.markSynced() : e,
    ]);
    return pending.length;
  } catch (_) {
    return 0;
  }
}
