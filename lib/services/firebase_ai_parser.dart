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

/// Pesan error model-sibuk? (500/quota/penuh) → pantas retry + ganti
/// model. Murni agar testable; pencocokan case-insensitive.
bool isBusyMessage(String m) {
  final t = m.toLowerCase();
  return t.contains('500') ||
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
