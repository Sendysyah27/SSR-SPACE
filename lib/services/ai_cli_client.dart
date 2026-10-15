import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'ai_soul.dart';
import 'firebase_ai_parser.dart';

// AI via MethodChannel ke native Kotlin (ZenProvider).
//
// Latar: native binary (libopencode.so) di-bundle tapi Android memblokir
// eksekusi/pencarian path-nya (3 strategi + MethodChannel getNativeLibDir
// semuanya gagal). Solusi: hapus jalur binary, pakai HTTP langsung via
// Kotlin ZenProvider yang key-nya tersimpan aman di EncryptedSharedPreferences.
//
// Cara kerja:
//  1. aiChatViaCli(): panggil MethodChannel 'ssr_space/ai' method 'complete'.
//  2. Kotlin ZenProvider POST ke https://opencode.ai/zen/v1/chat/completions.
//  3. Hasil dikembalikan ke Dart.
// Throw [AiFailure] jujur (kode: empty | timeout | denied | server).

/// Nama provider untuk tracking.
const cliProviderName = 'zen-http';

const cliTimeout = Duration(seconds: 30);

String _snip(String s, [int max = 300]) =>
    s.length <= max ? s : '${s.substring(0, max)}...';

/// Channel ke native AI bridge.
const _aiChannel = MethodChannel('ssr_space/ai');

/// Cek apakah AI tersedia (ada key). Untuk hide/disable fitur, bukan error.
Future<bool> aiHasKey() async {
  try {
    final has = await _aiChannel.invokeMethod<bool>('hasKey');
    return has ?? false;
  } catch (_) {
    return false;
  }
}

/// Buka layar pengaturan AI.
Future<void> aiOpenSettings() async {
  try {
    await _aiChannel.invokeMethod('openSettings');
  } catch (_) {}
}

Future<({String text, String provider})> aiChatViaCli(
  String prompt, {
  List<int>? imageBytes,
  String? mimeType,
  List<({bool mine, String text})>? history,
  String? dataContext,
}) async {
  if (prompt.trim().isEmpty) {
    throw const AiFailure('empty', 'prompt kosong');
  }

  // Catatan: imageBytes belum didukung via MethodChannel (butuh base64).
  // Untuk sekarang, abaikan gambar jika ada.
  if (imageBytes != null && imageBytes.isNotEmpty) {
    // TODO: encode base64 dan kirim via channel jika dibutuhkan
  }

  final convo = (history == null || history.isEmpty)
      ? ''
      : '${chatHistoryBlock(history)}\n';
  final data = (dataContext ?? '').trim().isNotEmpty
      ? '${dataContext!.trim()}\n'
      : '';
  final full = '$convo$data$prompt';

  // Mask data sensitif sebelum kirim (nomor panjang >= 10 digit)
  final masked = _maskLongNumbers(full);

  try {
    final text = await _aiChannel
        .invokeMethod<String>('complete', {'prompt': masked})
        .timeout(cliTimeout);
    if (text == null || text.trim().isEmpty) {
      throw const AiFailure('server', '[AI] response kosong');
    }
    return (text: text, provider: cliProviderName);
  } on PlatformException catch (e) {
    // Map error code dari Kotlin ke AiFailure
    switch (e.code) {
      case 'NO_KEY':
        throw const AiFailure('denied', '[AI] Belum ada API key. Buka Pengaturan AI.');
      case 'INVALID_KEY':
        throw const AiFailure('denied', '[AI] API key salah.');
      case 'RATE_LIMITED':
        throw const AiFailure('server', '[AI] Limit terlampaui, coba lagi nanti.');
      case 'MODEL_UNAVAILABLE':
        throw const AiFailure('server', '[AI] Model tidak tersedia.');
      case 'OFFLINE':
        throw const AiFailure('server', '[AI] Offline. Periksa koneksi.');
      case 'INVALID':
        throw AiFailure('empty', '[AI] ${e.message ?? 'prompt invalid'}');
      default:
        throw AiFailure('server', '[AI] ${e.message ?? 'gagal'}');
    }
  } on TimeoutException {
    throw const AiFailure('timeout', '[AI] Timeout.');
  } catch (e) {
    if (e is AiFailure) rethrow;
    throw AiFailure('server', '[AI] ${_snip(e.toString())}');
  }
}

/// Mask nomor panjang (>= 10 digit) untuk keamanan.
String _maskLongNumbers(String text) {
  return text.replaceAll(RegExp(r'\d{10,}'), '[MASKED]');
}

// ---------------------------------------------------------------------------
// Legacy: fungsi-fungsi binary di bawah ini sudah tidak dipakai.
// Disimpan sebagai dokumentasi, akan dihapus di versi berikutnya.
// ---------------------------------------------------------------------------

/// DEPRECATED: tidak lagi dipakai. Binary native dihapus.
Future<String> ensureCliBinary() async {
  throw const AiFailure(
      'server', '[CLI] Binary native sudah dihapus. Pakai HTTP via MethodChannel.');
}
