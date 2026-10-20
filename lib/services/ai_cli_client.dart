import 'dart:async';

import 'package:flutter/services.dart';

import 'ai_key_store.dart';
import 'ai_server_client.dart';
import 'ai_soul.dart';
import 'firebase_ai_parser.dart';
import 'supabase_config.dart';

// Router AI Mang AI (sejak 2.82.13+280):
//  1. 'server' (DEFAULT): Edge Function `mang-ai-chat` -> AI Gateway
//     (Cloudflare Worker) -> free-tier OpenCode. Lihat
//     ai_server_client.dart. Jalan untuk SEMUA user (cukup login +
//     anggota workspace); kuota per plan ditegakkan server.
//  2. 'zen' (opt-in): MethodChannel 'ssr_space/ai' method 'complete'
//     ke Kotlin ZenProvider (https://opencode.ai/zen/v1) dengan API
//     key milik user sendiri (Pengaturan AI).
//
// Jalur 'local' (opencode serve lokal di Termux) DIHAPUS dari jalur
// eksekusi: baseUrl + password lokal tidak lagi dipakai di sini.
// MethodChannel 'completeWithImage' native juga tidak lagi dipakai —
// gambar selalu lewat server (model vision).
//
// Throw [AiFailure] jujur (kode: empty | timeout | denied | server).

/// Nama provider Zen untuk tracking.
const cliProviderName = 'zen-http';

/// Nama provider lokal untuk tracking (label riwayat lama saja).
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

/// Cek apakah AI tersedia. Untuk hide/disable fitur, bukan error.
/// Provider server: cukup ada sesi Supabase. Provider zen: ada API key.
Future<bool> aiHasKey() async {
  final provider = await aiProviderId();
  if (provider != 'zen') {
    try {
      return SupabaseConfig.client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }
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
  // System prompt kustom (mis. scan struk). null = default.
  String? system,
  // Dulu: paksa provider lokal. Sejak 2.82.13+280 parameter ini berarti
  // paksa jalur SERVER tanpa melihat prefs — nama parameter dipertahankan
  // agar pemanggil lama tidak berubah, perilaku: true -> server.
  bool forceLocal = false,
  // Jenis pemakaian untuk kuota server: 'chat' | 'receipt' | 'quick'.
  // Diteruskan ke aiChatViaServer.
  String kind = 'chat',
  // Timeout kustom; null = cliTimeout (30 dtk). Vision scan pakai
  // visionScanTimeout (120 dtk) karena output item bisa sangat panjang.
  Duration? timeout,
}) async {
  if (prompt.trim().isEmpty) {
    throw const AiFailure('empty', 'prompt kosong');
  }

  // Default baru: semua lewat server (teks DAN gambar). 'zen' hanya
  // bila user eksplisit memilihnya; forceLocal (paksa server) menang.
  if (await aiProviderId() != 'zen' || forceLocal) {
    return aiChatViaServer(
      prompt,
      imageBytes: imageBytes,
      mimeType: mimeType,
      history: history,
      dataContext: dataContext,
      system: system,
      kind: kind,
      timeout: timeout,
    );
  }

  // --- Jalur 'zen': MethodChannel 'complete' ke native ZenProvider. ---
  final convo = (history == null || history.isEmpty)
      ? ''
      : '${chatHistoryBlock(history)}\n';
  final data = (dataContext ?? '').trim().isNotEmpty
      ? '${dataContext!.trim()}\n'
      : '';
  final full = '$convo$data$prompt';

  // Mask data sensitif sebelum kirim (nomor panjang >= 10 digit)
  final masked = _maskLongNumbers(full);

  final args = <String, dynamic>{'prompt': masked};
  final effectiveTimeout = timeout ?? cliTimeout;
  // Sampaikan ke native agar HttpURLConnection ikut longgar (bukan cuma
  // dinding Dart). Native default 30 dtk bila argumen tak ada.
  args['timeoutMs'] = effectiveTimeout.inMilliseconds;
  if (system != null && system.trim().isNotEmpty) {
    args['system'] = system;
  }

  try {
    final text = await _aiChannel
        .invokeMethod<String>('complete', args)
        .timeout(effectiveTimeout);
    if (text == null || text.trim().isEmpty) {
      throw const AiFailure('server', '[AI] response kosong');
    }
    return (text: text, provider: cliProviderName);
  } on PlatformException catch (e) {
    // Map error code dari Kotlin ke AiFailure
    switch (e.code) {
      case 'NO_KEY':
        throw const AiFailure(
            'denied', '[AI] Belum ada API key. Buka Pengaturan AI.');
      case 'INVALID_KEY':
        throw const AiFailure('denied', '[AI] API key salah.');
      case 'RATE_LIMITED':
        throw const AiFailure(
            'server', '[AI] Limit terlampaui, coba lagi nanti.');
      case 'MODEL_UNAVAILABLE':
        throw const AiFailure('server', '[AI] Model tidak tersedia.');
      case 'EMPTY':
        throw const AiFailure('server', '[AI] AI tidak mengembalikan teks.');
      case 'OFFLINE':
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
  throw const AiFailure('server',
      '[CLI] Binary native sudah dihapus. Pakai HTTP via MethodChannel.');
}
