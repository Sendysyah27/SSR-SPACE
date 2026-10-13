import 'dart:async';

import 'ai_draft.dart';

// Orkestrasi AI fallback parser struk via Firebase AI Logic.
// File SENGAJA tanpa import Flutter/plugin supaya bisa diverifikasi
// via `dart` murni (pola ai_draft.dart). Factory model Firebase yang
// butuh plugin tinggal di `firebase_ai_factory.dart`.
// Rule-based tetap utama; fungsi ini hanya dipanggil bila rule tak
// confident. Tanpa upload foto (teks OCR saja), timeout 30 dtk,
// retry 1x khusus timeout/jaringan. Selain itu gagal jujur.
const firebaseAiTimeout = Duration(seconds: 30);

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
String aiFailureTrKey(String code, {required bool loggedIn}) =>
    (code == 'denied' && !loggedIn) ? 'ai_need_google' : 'ai_fail';

/// Teks OCR -> [AiDraft]. Null = AI tak bisa dipakai (pemanggil fallback
/// manual). Melempar [AiFailure] dengan sebab jujur.
Future<AiDraft?> parseReceiptFirebase({
  required String ocrText,
  required AiGenerate generate,
}) async {
  if (ocrText.trim().isEmpty) return null;
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final text = await generate(
        aiReceiptPrompt(ocrText),
      ).timeout(firebaseAiTimeout);
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
