import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'ai_draft.dart';
import 'firebase_ai_parser.dart';

// Provider KEEMPAT: OpenCode Zen via proxy VPS (muse-spark-1.3).
// Proxy memimik header OpenCode; app cukup POST {ocr_text, api_key}.
// Urutan: Gemini -> OpenRouter -> Zen -> Firebase. Timeout 60 dtk,
// retry 1x khusus timeout/jaringan. Prefix [Zen] untuk diagnosis.
const zenProxyDefault = 'http://87.81.230.71:8766/zen-parse';
const aiZenTimeout = Duration(seconds: 60);

/// Hasil urai respons proxy ada di ai_draft.dart (murni, testable):
/// zenParseResponse. Klien ini hanya transport HTTP.

/// Teks OCR -> [AiDraft] via proxy Zen. Null = tak bisa dipakai
/// (pemanggil lanjut ke Firebase). Melempar [AiFailure] jujur.
Future<AiDraft?> parseReceiptZen({
  required String apiKey,
  required String ocrText,
  String? url,
  http.Client? client,
}) async {
  if (apiKey.trim().isEmpty || ocrText.trim().isEmpty) return null;
  final endpoint =
      (url ?? '').trim().isNotEmpty ? url!.trim() : zenProxyDefault;
  final httpClient = client ?? http.Client();
  final owned = client == null;
  try {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await httpClient
            .post(
              Uri.parse(endpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(
                  {'ocr_text': ocrText, 'api_key': apiKey.trim()}),
            )
            .timeout(aiZenTimeout);
        if (res.statusCode < 200 || res.statusCode >= 300) {
          if (res.statusCode >= 500 && attempt == 0) continue;
          var snippet = res.body;
          if (snippet.length > 300) snippet = snippet.substring(0, 300);
          throw AiFailure(
              'server', '[Zen] HTTP ${res.statusCode} $snippet');
        }
        dynamic body;
        try {
          body = jsonDecode(res.body);
        } catch (_) {
          if (attempt == 0) continue;
          throw const AiFailure('server', '[Zen] body bukan JSON');
        }
        return zenParseResponse(body).draft;
      } on AiFailure {
        rethrow;
      } on TimeoutException catch (e) {
        if (attempt == 0) continue;
        throw AiFailure('timeout', '[Zen] $e');
      } catch (e) {
        if (attempt == 0) continue;
        throw AiFailure('network', '[Zen] $e');
      }
    }
    throw const AiFailure('network', '[Zen] percobaan habis');
  } finally {
    if (owned) httpClient.close();
  }
}

/// Chat mentah ke proxy Zen (untuk Tes AI): prompt bebas -> (teks, provider).
/// Throw [AiFailure] jujur.
Future<({String text, String provider})> zenChatRaw({
  required String apiKey,
  required String prompt,
  String? url,
  http.Client? client,
}) async {
  if (apiKey.trim().isEmpty || prompt.trim().isEmpty) {
    throw const AiFailure('empty', '[Zen] kunci/prompt kosong');
  }
  // Kirim sebagai "struk" satu baris; proxy teruskan ke model apa adanya.
  // Respons data Map -> encode lagi; String -> pakai langsung.
  final endpoint =
      (url ?? '').trim().isNotEmpty ? url!.trim() : zenProxyDefault;
  final httpClient = client ?? http.Client();
  final owned = client == null;
  try {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await httpClient
            .post(
              Uri.parse(endpoint),
              headers: {'Content-Type': 'application/json'},
              body:
                  jsonEncode({'ocr_text': prompt, 'api_key': apiKey.trim()}),
            )
            .timeout(aiZenTimeout);
        if (res.statusCode < 200 || res.statusCode >= 300) {
          if (res.statusCode >= 500 && attempt == 0) continue;
          var snippet = res.body;
          if (snippet.length > 300) snippet = snippet.substring(0, 300);
          throw AiFailure(
              'server', '[Zen] HTTP ${res.statusCode} $snippet');
        }
        dynamic body;
        try {
          body = jsonDecode(res.body);
        } catch (_) {
          if (attempt == 0) continue;
          throw const AiFailure('server', '[Zen] body bukan JSON');
        }
        if (body is! Map) {
          throw const AiFailure('server', '[Zen] body bukan Map');
        }
        final provider = body['provider'] is String
            ? body['provider'] as String
            : 'zen';
        if (body['ok'] != true) {
          // Pakai ulang klasifikasi error yang sama.
          zenParseResponse(body);
          throw const AiFailure('server', '[Zen] proxy gagal');
        }
        final data = body['data'];
        final text = data is String
            ? data
            : data is Map
                ? jsonEncode(data)
                : '';
        if (text.trim().isEmpty) {
          throw const AiFailure('empty', '[Zen] tanpa teks');
        }
        return (text: text, provider: provider);
      } on AiFailure {
        rethrow;
      } on TimeoutException catch (e) {
        if (attempt == 0) continue;
        throw AiFailure('timeout', '[Zen] $e');
      } catch (e) {
        if (attempt == 0) continue;
        throw AiFailure('network', '[Zen] $e');
      }
    }
    throw const AiFailure('network', '[Zen] percobaan habis');
  } finally {
    if (owned) httpClient.close();
  }
}
