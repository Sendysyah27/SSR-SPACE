import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'ai_draft.dart';
import 'firebase_ai_parser.dart';

// Provider KETIGA parser struk: OpenRouter free tier (OpenAI-compatible).
// Urutan: Gemini key -> OpenRouter -> Firebase. Timeout 60 dtk samakan
// yang lain, retry 1x khusus timeout/jaringan/server-5xx. Prefix
// [OpenRouter] agar sumber error jelas di diagnosis.
const aiOrEndpoint = 'https://openrouter.ai/api/v1/chat/completions';

// Model free terverifikasi LIVE via GET /api/v1/models (2026-10-13):
// llama-3.1-8b:free, gemma-2-9b-it:free, qwen-2.5-7b:free SUDAH PENSIUN
// (itulah 404 kemarin). Rotasi otomatis bila 404/model tak tersedia.
const aiOrModels = [
  'google/gemma-4-31b-it:free',
  'google/gemma-4-26b-a4b-it:free',
  'cohere/north-mini-code:free',
];
const aiOrModel = 'google/gemma-4-31b-it:free';
const aiOrTimeout = Duration(seconds: 60);
const aiOrReferer = 'https://github.com/Sendysyah27/SSR-SPACE';
const aiOrTitle = 'SSR SPACE';

/// Teks OCR -> [AiDraft] via OpenRouter. Null = tak bisa dipakai
/// (pemanggil lanjut ke Firebase). Melempar [AiFailure] jujur.
Future<AiDraft?> parseReceiptOr({
  required String apiKey,
  required String ocrText,
  String? model,
  http.Client? client,
}) async {
  if (apiKey.trim().isEmpty || ocrText.trim().isEmpty) return null;
  final content = await orChatRaw(
    apiKey: apiKey,
    prompt: aiReceiptPrompt(ocrText),
    model: model,
    client: client,
  );
  return parseAiDraft(content);
}

/// Chat mentah ke OpenRouter (untuk Tes AI): prompt bebas -> teks mentah.
/// Throw [AiFailure] jujur (selalu bawa cuplikan body bila ada).
/// [model]: paksa satu model; kosong = rotasi [aiOrModels] saat 404.
/// [onModel]: nama model yang menjawab (untuk label Tes AI).
Future<String> orChatRaw({
  required String apiKey,
  required String prompt,
  String? model,
  http.Client? client,
  void Function(String model)? onModel,
}) async {
  if (apiKey.trim().isEmpty || prompt.trim().isEmpty) {
    throw const AiFailure('empty', '[OpenRouter] kunci/prompt kosong');
  }
  final names = (model ?? '').trim().isNotEmpty ? [model!.trim()] : aiOrModels;
  final httpClient = client ?? http.Client();
  final owned = client == null;
  String? lastDetail;
  try {
    for (var mi = 0; mi < names.length; mi++) {
      final name = names[mi];
      try {
        final res = await httpClient
            .post(
              Uri.parse(aiOrEndpoint),
              headers: {
                'Authorization': 'Bearer ${apiKey.trim()}',
                'Content-Type': 'application/json',
                'HTTP-Referer': aiOrReferer,
                'X-Title': aiOrTitle,
              },
              body: jsonEncode({
                'model': name,
                'temperature': 0.1,
                'max_tokens': 1500,
                'messages': [
                  {'role': 'user', 'content': prompt},
                ],
              }),
            )
            .timeout(aiOrTimeout);
        if (res.statusCode == 401 || res.statusCode == 403) {
          var snippet = res.body;
          if (snippet.length > 300) snippet = snippet.substring(0, 300);
          throw AiFailure('denied', '[OpenRouter] $snippet');
        }
        if (res.statusCode == 429) {
          var snippet = res.body;
          if (snippet.length > 300) snippet = snippet.substring(0, 300);
          throw AiFailure('quota', '[OpenRouter] $snippet');
        }
        if (res.statusCode == 404) {
          var snippet = res.body;
          if (snippet.length > 300) snippet = snippet.substring(0, 300);
          debugPrint('openrouter 404 ($name): $snippet');
          lastDetail = '[OpenRouter] HTTP 404 ($name) $snippet';
          continue;
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          var snippet = res.body;
          if (snippet.length > 300) snippet = snippet.substring(0, 300);
          if (res.statusCode >= 500) {
            lastDetail = '[OpenRouter] HTTP ${res.statusCode} ($name) $snippet';
            continue;
          }
          throw AiFailure(
              'server', '[OpenRouter] HTTP ${res.statusCode} ($name) $snippet');
        }
        dynamic body;
        try {
          body = jsonDecode(res.body);
        } catch (_) {
          throw const AiFailure('server', '[OpenRouter] body bukan JSON');
        }
        final content = openAiContentFromBody(body);
        if (content == null) {
          throw const AiFailure('empty', '[OpenRouter] tanpa teks');
        }
        onModel?.call(name);
        return content;
      } on AiFailure {
        rethrow;
      } on TimeoutException catch (e) {
        throw AiFailure('timeout', '[OpenRouter] ($name) $e');
      } catch (e) {
        throw AiFailure('network', '[OpenRouter] ($name) $e');
      }
    }
    throw AiFailure(
        'server', lastDetail ?? '[OpenRouter] semua model tak tersedia');
  } finally {
    if (owned) httpClient.close();
  }
}
