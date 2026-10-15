import 'dart:async';

import 'package:flutter/services.dart';

import 'ai_key_store.dart';
import 'ai_soul.dart';
import 'firebase_ai_parser.dart';

// AI via MethodChannel ke native Kotlin (ZenProvider / LocalOpenCodeProvider).
//
// Latar: native binary (libopencode.so) di-bundle tapi Android memblokir
// eksekusi/pencarian path-nya (3 strategi + MethodChannel getNativeLibDir
// semuanya gagal). Solusi: HTTP via Kotlin yang key-nya tersimpan aman.
//
// Dua provider (pilihan di layar Mang AI, prefs ai_provider):
//  1. 'zen' (default): Kotlin ZenProvider POST ke
//     https://opencode.ai/zen/v1/chat/completions (key = Zen key).
//  2. 'local': Kotlin LocalOpenCodeProvider ke opencode serve lokal
//     (baseUrl prefs, password = secure storage Dart, dikirim per-call,
//     TIDAK PERNAH di-log).
//
// Cara kerja:
//  1. aiChatViaCli(): panggil MethodChannel 'ssr_space/ai' method 'complete'.
//  2. Hasil dikembalikan ke Dart.
// Throw [AiFailure] jujur (kode: empty | timeout | denied | server).

/// Nama provider untuk tracking.
const cliProviderName = 'zen-http';

/// Nama provider lokal untuk tracking.
const localProviderName = 'opencode-lokal';

const cliTimeout = Duration(seconds: 30);

/// Timeout khusus vision scan (gambar): output JSON bisa sangat panjang
/// (puluhan item struk) + upload base64. 120 dtk memberi ruang untuk
/// model yang lambat tanpa menggantung selamanya.
const visionScanTimeout = Duration(seconds: 120);

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
  // System prompt kustom untuk native (mis. scan struk). null = default.
  String? system,
  // Paksa provider lokal tanpa melihat prefs (untuk scan struk).
  bool forceLocal = false,
  // Timeout kustom; null = cliTimeout (30 dtk). Vision scan pakai
  // visionScanTimeout (120 dtk) karena output item bisa sangat panjang.
  Duration? timeout,
}) async {
  if (prompt.trim().isEmpty) {
    throw const AiFailure('empty', 'prompt kosong');
  }

  final hasImage = imageBytes != null && imageBytes.isNotEmpty;

  final convo = (history == null || history.isEmpty)
      ? ''
      : '${chatHistoryBlock(history)}\n';
  final data = (dataContext ?? '').trim().isNotEmpty
      ? '${dataContext!.trim()}\n'
      : '';
  final full = '$convo$data$prompt';

  // Mask data sensitif sebelum kirim (nomor panjang >= 10 digit)
  final masked = _maskLongNumbers(full);

  // Provider lokal: baseUrl + password per-call (password tak pernah di-log).
  final useLocal = forceLocal || await aiProviderId() == 'local';
  final args = <String, dynamic>{'prompt': masked};
  final effectiveTimeout = timeout ?? cliTimeout;
  // Sampaikan ke native agar HttpURLConnection ikut longgar (bukan cuma
  // dinding Dart). Native default 30 dtk bila argumen tak ada.
  args['timeoutMs'] = effectiveTimeout.inMilliseconds;
  if (system != null && system.trim().isNotEmpty) {
    args['system'] = system;
  }
  if (useLocal) {
    final pass = await readLocalPass();
    if (pass == null || pass.isEmpty) {
      throw const AiFailure('denied',
          '[AI] Belum ada password OpenCode lokal. Isi di Mang AI.');
    }
    args['provider'] = 'local';
    args['baseUrl'] = await aiBaseUrl();
    args['localPassword'] = pass;
  }

  // Vision: pakai completeWithImage jika ada gambar + provider lokal
  final method = (hasImage && useLocal) ? 'completeWithImage' : 'complete';
  if (hasImage && useLocal) {
    args['imageBytes'] = imageBytes;
    args['mimeType'] = mimeType ?? 'image/jpeg';
  }

  try {
    final text = await _aiChannel
        .invokeMethod<String>(method, args)
        .timeout(effectiveTimeout);
    if (text == null || text.trim().isEmpty) {
      throw const AiFailure('server', '[AI] response kosong');
    }
    return (text: text, provider: useLocal ? localProviderName : cliProviderName);
  } on PlatformException catch (e) {
    // Map error code dari Kotlin ke AiFailure
    switch (e.code) {
      case 'NO_KEY':
        throw const AiFailure('denied', '[AI] Belum ada API key. Buka Pengaturan AI.');
      case 'NO_LOCAL_PASS':
        throw const AiFailure('denied',
            '[AI] Belum ada password OpenCode lokal. Isi di Mang AI.');
      case 'INVALID_KEY':
        throw const AiFailure('denied', '[AI] API key salah.');
      case 'RATE_LIMITED':
        throw const AiFailure('server', '[AI] Limit terlampaui, coba lagi nanti.');
      case 'MODEL_UNAVAILABLE':
        throw const AiFailure('server', '[AI] Model tidak tersedia.');
      case 'EMPTY':
        throw const AiFailure('server', '[AI] AI tidak mengembalikan teks.');
      case 'OFFLINE':
        // Pesan native sudah jujur (mis. "Jalankan opencode serve di Termux").
        throw AiFailure('server', '[AI] ${e.message ?? 'Offline'}');
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
