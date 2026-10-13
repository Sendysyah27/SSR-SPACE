import 'dart:async';

import 'ai_draft.dart';

// Orkestrasi AI fallback parser struk via Firebase AI Logic.
// File SENGAJA tanpa import Flutter/plugin supaya bisa diverifikasi
// via `dart` murni (pola ai_draft.dart). Factory model Firebase yang
// butuh plugin tinggal di `firebase_ai_factory.dart`.
// Rule-based tetap utama; fungsi ini hanya dipanggil bila rule tak
// confident. Tanpa upload foto (teks OCR saja), timeout 60 dtk,
// retry 1x khusus timeout/jaringan. Selain itu gagal jujur.
// Pakai print (bukan debugPrint) agar tetap jalan di `dart` murni
// dan tampil di logcat rilis; yang di-log hanya durasi + panjang
// teks, BUKAN isi struk user.
const firebaseAiTimeout = Duration(seconds: 60);

/// Log diagnosis (durasi + panjang teks, bukan isi struk). Sengaja print
/// mentah: file ini harus tetap jalan di `dart` murni tanpa Flutter,
/// jadi tak bisa pakai debugPrint/logging framework.
void _aiLog(String s) {
  // ignore: avoid_print
  print(s);
}

class AiFailure implements Exception {
  // timeout | network | denied | server | empty
  final String code;

  /// Pesan error asli (diagnosis jujur di UI, tak diupload).
  final String? detail;
  const AiFailure(this.code, [this.detail]);

  @override
  String toString() => 'AiFailure($code)${detail == null ? '' : ': $detail'}';
}

/// Penanda dari factory: model menolak (belum login / quota / 403).
/// Dipetakan jadi [AiFailure] `denied` tanpa retry.
class AiDenied implements Exception {
  final String? detail;
  const AiDenied([this.detail]);

  @override
  String toString() => 'AiDenied${detail == null ? '' : ': $detail'}';
}

/// Penanda dari factory: token App Check invalid/gagal.
/// Dipetakan jadi [AiFailure] `app_check` tanpa retry (bukan denied,
/// bukan network — sebabnya spesifik dan butuh aksi berbeda).
class AiAppCheck implements Exception {
  final String? detail;
  const AiAppCheck([this.detail]);

  @override
  String toString() => 'AiAppCheck${detail == null ? '' : ': $detail'}';
}

/// Satu pemanggilan model: prompt -> teks JSON mentah (null = kosong).
typedef AiGenerate = Future<String?> Function(String prompt);

/// Kunci strings untuk [AiFailure.code]. `denied` hanya berarti
/// "belum login" bila tanpa sesi; dengan sesi hidup = ditolak/kuota
/// (pesan gagal umum yang jujur, bukan tuduhan belum login).
/// `server` = model sibuk (500/penuh) → pesan ramah + tombol Coba Lagi.
String aiFailureTrKey(String code, {required bool loggedIn}) {
  if (code == 'server') return 'ai_busy';
  return (code == 'denied' && !loggedIn) ? 'ai_need_google' : 'ai_fail';
}

/// Pesan error kuota? (habis/batas/429) → jangan retry/rotasi,
/// langsung vonis jujur. Murni agar testable.
bool isQuotaMessage(String m) {
  final t = m.toLowerCase();
  return t.contains('quota') ||
      t.contains('exhausted') ||
      t.contains('429') ||
      t.contains('rate limit') ||
      t.contains('rate-limit') ||
      t.contains('ratelimit');
}

/// Ambil waktu tunggu dari pesan kuota, atau null bila tak disebut.
/// Pola: "retry in 12h/30m/45s", "retryDelay: 3600s", "try again in 2 hours".
Duration? parseQuotaRetry(String? detail) {
  if (detail == null) return null;
  final t = detail.toLowerCase();
  final rd = RegExp(r'retrydelay"?\s*:?\s*"?(\d+(?:\.\d+)?)s')
      .firstMatch(t);
  if (rd != null) {
    final v = double.tryParse(rd.group(1)!) ?? 0;
    if (v > 0) return Duration(seconds: v.round());
  }
  var m = RegExp(r'retry\s+in\s+(\d+(?:\.\d+)?)\s*(h|hour|m|min|s|sec)')
      .firstMatch(t);
  m ??= RegExp(r'try again in\s+(\d+(?:\.\d+)?)\s*(hour|minute|second)')
      .firstMatch(t);
  if (m == null) return null;
  final v = double.tryParse(m.group(1)!) ?? 0;
  if (v <= 0) return null;
  final u = m.group(2)!;
  if (u.startsWith('h')) return Duration(seconds: (v * 3600).round());
  if (u.startsWith('m')) return Duration(seconds: (v * 60).round());
  return Duration(seconds: v.round());
}

/// "Coba lagi dalam 12 jam." (Bahasa Indonesia tetap — diagnosis teknis,
/// seperti reachReport.)
String quotaWaitText(Duration d) {
  final s = d.inSeconds;
  if (s < 60) return 'Coba lagi dalam $s detik.';
  final h = s ~/ 3600, m = (s % 3600) ~/ 60;
  if (h > 0 && m > 0) return 'Coba lagi dalam $h jam $m menit.';
  if (h > 0) return 'Coba lagi dalam $h jam.';
  return 'Coba lagi dalam $m menit.';
}

/// Baris utuh untuk UI: "Kuota AI habis. Coba lagi dalam 12 jam."
/// Tanpa info waktu di pesan = ajakan coba nanti.
String quotaWaitLine(String? detail) {
  final w = parseQuotaRetry(detail);
  if (w == null) return 'Kuota AI habis. Coba lagi nanti.';
  return 'Kuota AI habis. ${quotaWaitText(w)}';
}

/// Pilih error AI mana yang ditampilkan ke user.
/// Aturan: pesan kuota Firebase DITEKAN bila ada kunci user (Gemini /
/// OpenRouter) — fallback tak boleh menutupi status primer; kuota tampil
/// hanya bila SEMUA path yang dicoba habis (pakai tunggu terlama).
/// Null = semua tak jalan.
AiFailure? pickAiError({
  AiFailure? gemini,
  AiFailure? openRouter,
  AiFailure? firebase,
  required bool hasKey,
}) {
  AiFailure quotaMax(AiFailure a, AiFailure b) {
    final da = parseQuotaRetry(a.detail);
    final db = parseQuotaRetry(b.detail);
    if (da != null && db != null) {
      return AiFailure('quota', da >= db ? a.detail : b.detail);
    }
    return AiFailure('quota', a.detail ?? b.detail);
  }

  final gq = gemini?.code == 'quota';
  final oq = openRouter?.code == 'quota';
  final fq = firebase?.code == 'quota';
  final nQuota = (gq ? 1 : 0) + (oq ? 1 : 0) + (fq ? 1 : 0);
  final nTried = (gemini != null ? 1 : 0) +
      (openRouter != null ? 1 : 0) +
      (firebase != null ? 1 : 0);
  if (nQuota > 0 && nQuota == nTried && nTried > 0) {
    var acc = gemini ?? openRouter ?? firebase!;
    for (final e in [gemini, openRouter, firebase]) {
      final q = e;
      if (q != null && q.code == 'quota') acc = quotaMax(acc, q);
    }
    return acc;
  }
  if (fq && hasKey) return openRouter ?? gemini;
  return firebase ?? openRouter ?? gemini;
}

/// Pesan error model-sibuk? (500/quota/penuh) → pantas retry + ganti
/// model, KECUALI kuota murni (ditangani isQuotaMessage duluan).
/// Murni agar testable; pencocokan case-insensitive.
bool isBusyMessage(String m) {
  final t = m.toLowerCase();
  return t.contains('500') ||
      t.contains('503') ||
      t.contains('unavailable') ||
      t.contains('high demand') ||
      t.contains('overloaded') ||
      t.contains('resource-exhausted') ||
      t.contains('resource exhausted') ||
      t.contains('429') ||
      t.contains('quota') ||
      t.contains('exhausted');
}

/// Baris laporan keterjangkauan server (murni, testable).
/// Status HTTP APAPUN = host hidup (root memang 404, itu buktinya).
String reachReport({int? status, String? error}) {
  if (status != null) return 'NET: host hidup (HTTP $status)';
  return 'NET: BUNTU (${error ?? 'tak dikenal'})';
}

/// Body REST fallback Gemini Developer API (Plan B bila SDK hang).
/// Murni (tanpa import plugin) agar testable via `dart`.
Map<String, Object?> restPromptBody(String prompt) => {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
    };

/// Respons JSON REST -> teks pertama, atau null bila struktur tak pas.
/// Tak pernah throw (body rusak = null, bukan crash).
String? parseRestText(dynamic body) {
  try {
    if (body is! Map) return null;
    final cands = body['candidates'];
    if (cands is! List || cands.isEmpty || cands.first is! Map) return null;
    final content = (cands.first as Map)['content'];
    if (content is! Map) return null;
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty || parts.first is! Map) return null;
    final text = (parts.first as Map)['text'];
    if (text is! String || text.trim().isEmpty) return null;
    return text;
  } catch (_) {
    return null;
  }
}

/// Teks OCR -> [AiDraft]. Null = AI tak bisa dipakai (pemanggil fallback
/// manual). Melempar [AiFailure] dengan sebab jujur.
Future<AiDraft?> parseReceiptFirebase({
  required String ocrText,
  required AiGenerate generate,
}) async {
  if (ocrText.trim().isEmpty) return null;
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final t0 = DateTime.now();
      _aiLog('firebase ai kirim (attempt $attempt, ${ocrText.length} chr)...');
      final text = await generate(
        aiReceiptPrompt(ocrText),
      ).timeout(firebaseAiTimeout);
      _aiLog('firebase ai jawab ${DateTime.now().difference(t0).inMilliseconds}ms');
      if (text == null || text.trim().isEmpty) {
        throw const AiFailure('empty');
      }
      final draft = parseAiDraft(text);
      if (draft == null && attempt == 0) continue;
      return draft;
    } on AiDenied catch (e) {
      throw AiFailure('denied', e.detail);
    } on AiAppCheck catch (e) {
      throw AiFailure('app_check', e.detail);
    } on AiFailure {
      rethrow;
    } on TimeoutException catch (e) {
      if (attempt == 0) continue;
      throw AiFailure('timeout', '$e');
    } catch (e) {
      if (attempt == 0) continue;
      throw AiFailure('network', '$e');
    }
  }
  throw const AiFailure('network');
}
