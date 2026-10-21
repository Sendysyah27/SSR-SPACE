// Kosakata state bernama Mode Asisten (batch 285 tahap D, pola state
// eksplisit Ollo): petakan [AiFailure] dari panggilan chat ke nama
// state yang punya kartu UI ramah. Murni (testable), tanpa import
// Flutter — cocok untuk `flutter test`.

import 'firebase_ai_parser.dart';

/// State bernama error Mode Asisten:
/// 'kuota_habis' | 'rate_limited' | 'jaringan' | 'server_tidak_tersedia'.
/// Selalu mengembalikan salah satu (fallback server_tidak_tersedia),
/// agar Mode Asisten tak pernah menampilkan pesan error generik.
String assistantErrorState(AiFailure e) {
  final d = (e.detail ?? '').toLowerCase();
  // Kuota: EF 403 QUOTA_EXCEEDED ("[AI] Kuota AI bulan ini habis...")
  // maupun jalur provider 'quota'.
  if (e.code == 'quota' ||
      d.contains('kuota ai bulan ini habis') ||
      d.contains('quota_exceeded')) {
    return 'kuota_habis';
  }
  // Rate limit provider (429 / "limit terlampaui").
  if (d.contains('limit terlampaui') || d.contains('429')) {
    return 'rate_limited';
  }
  // Jaringan: timeout (Dart/native) maupun kegagalan koneksi.
  if (e.code == 'timeout' ||
      d.contains('timeout') ||
      d.contains('failed host lookup') ||
      d.contains('network is unreachable') ||
      d.contains('connection refused') ||
      d.contains('failed to connect') ||
      d.contains('socketexception') ||
      d.contains('127.0.0.1') ||
      d.contains('localhost')) {
    return 'jaringan';
  }
  return 'server_tidak_tersedia';
}
