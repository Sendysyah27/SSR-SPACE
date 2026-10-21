import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/org_prefs.dart';
import 'ai_pii.dart';
import 'supabase_config.dart';

// Umpan balik jawaban Mode Asisten (batch 285 tahap B, pola feedback
// Ollo): rating 👍 (1) / 👎 (-1) per balasan Asisten. Lokal dulu
// (SharedPreferences, pola ai_correction.dart): arsip + antrean sinkron
// best-effort ke tabel ai_assistant_feedback (migration_30 — apply via
// dashboard; selama belum apply, insert gagal senyap dan antrean
// menunggu). Konteks yang disimpan = cuplikan balasan yang SUDAH lewat
// maskPii dan dipotong aman — tak pernah teks mentah user.

/// Kunci prefs antrean feedback.
const _kFeedback = 'ai_assistant_feedback_v1';

/// Batas antrean lokal; entri tersinkron lama dibuang lebih dulu,
/// lalu entri tertua (offline lama tidak menumpuk tanpa batas).
const feedbackQueueCap = 50;

/// Panjang maks cuplikan konteks per feedback.
const feedbackContextCap = 200;

/// Cuplikan konteks aman untuk disimpan/dikirim: masking PII dulu,
/// lalu potong ke [feedbackContextCap] char. Murni.
String feedbackContext(String rawReply) {
  final masked = maskPii(rawReply).replaceAll('\n', ' ').trim();
  if (masked.length <= feedbackContextCap) return masked;
  return masked.substring(0, feedbackContextCap);
}

/// Satu entri feedback jawaban Asisten.
class AssistantFeedback {
  final String id;
  final int rating; // 1 = 👍, -1 = 👎
  final String context;
  final String createdAt; // ISO-8601 lokal
  final bool synced;

  const AssistantFeedback({
    required this.id,
    required this.rating,
    required this.context,
    required this.createdAt,
    this.synced = false,
  });

  AssistantFeedback markSynced() => AssistantFeedback(
        id: id,
        rating: rating,
        context: context,
        createdAt: createdAt,
        synced: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'rating': rating,
        'context': context,
        'created_at': createdAt,
        'synced': synced,
      };

  static AssistantFeedback? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final rating = raw['rating'];
    if (id is! String || id.isEmpty) return null;
    if (rating is! int || (rating != 1 && rating != -1)) return null;
    return AssistantFeedback(
      id: id,
      rating: rating,
      context: (raw['context'] as String?) ?? '',
      createdAt: (raw['created_at'] as String?) ?? '',
      synced: raw['synced'] == true,
    );
  }

  /// Baris insert ke tabel ai_assistant_feedback (migration_30).
  Map<String, dynamic> toRow(String orgId, String userId) => {
        'org_id': orgId,
        'user_id': userId,
        'rating': rating,
        'context': context,
      };
}

Future<List<AssistantFeedback>> loadAssistantFeedback() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kFeedback);
    if (raw == null || raw.isEmpty) return const [];
    final d = jsonDecode(raw);
    if (d is! List) return const [];
    return [
      for (final e in d)
        if (AssistantFeedback.fromJson(e) != null)
          AssistantFeedback.fromJson(e)!,
    ];
  } catch (_) {
    return const [];
  }
}

Future<void> _saveQueue(List<AssistantFeedback> items) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _kFeedback, jsonEncode([for (final e in items) e.toJson()]));
  } catch (_) {}
}

/// Pangkas antrean ke [feedbackQueueCap]: buang yang sudah tersinkron
/// (tertua dulu), baru yang tertua apa pun statusnya. Murni.
List<AssistantFeedback> capFeedbackQueue(List<AssistantFeedback> items) {
  var cur = List<AssistantFeedback>.of(items);
  while (cur.length > feedbackQueueCap) {
    final idx = cur.indexWhere((e) => e.synced);
    cur.removeAt(idx >= 0 ? idx : 0);
  }
  return cur;
}

/// Simpan satu feedback baru ke antrean lokal (rating 1/-1; selain itu
/// diabaikan). Konteks otomatis dimasking + dipotong. Tak pernah throw.
Future<void> saveAssistantFeedback({
  required int rating,
  required String replyText,
}) async {
  if (rating != 1 && rating != -1) return;
  try {
    final cur = await loadAssistantFeedback();
    final now = DateTime.now();
    cur.add(AssistantFeedback(
      id: 'fb-${now.microsecondsSinceEpoch}',
      rating: rating,
      context: feedbackContext(replyText),
      createdAt: now.toIso8601String(),
    ));
    await _saveQueue(capFeedbackQueue(cur));
  } catch (_) {}
}

/// Sinkron best-effort antrean pending ke tabel ai_assistant_feedback.
/// Return jumlah terkirim. Gagal (offline / belum login / migration_30
/// belum apply) -> 0 dan antrean tetap pending. Tak pernah throw.
Future<int> syncAssistantFeedback() async {
  try {
    final client = SupabaseConfig.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return 0;
    final orgId = await activeOrgId();
    if (orgId.isEmpty) return 0;
    final all = await loadAssistantFeedback();
    final pending = [for (final e in all) if (!e.synced) e];
    if (pending.isEmpty) return 0;
    await client.from('ai_assistant_feedback').insert([
      for (final e in pending) e.toRow(orgId, uid),
    ]);
    final sentIds = {for (final e in pending) e.id};
    await _saveQueue(capFeedbackQueue([
      for (final e in await loadAssistantFeedback())
        sentIds.contains(e.id) ? e.markSynced() : e,
    ]));
    return pending.length;
  } catch (_) {
    return 0;
  }
}
