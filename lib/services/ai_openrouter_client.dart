import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'ai_draft.dart';
import 'firebase_ai_parser.dart';

// Provider KETIGA parser struk: OpenRouter free tier (OpenAI-compatible).
// Urutan: Gemini key -> OpenRouter -> Firebase. Timeout 60 dtk samakan
// yang lain, retry 1x khusus timeout/jaringan/server-5xx. Prefix
// [OpenRouter] agar sumber error jelas di diagnosis.
const aiOrEndpoint = 'https://openrouter.ai/api/v1/chat/completions';

// Model free pilihan user. Ganti 1 const ini bila pensiun/diganti.
// Kandidat stabil lain (contoh): google/gemma-2-9b-it:free.
const aiOrModel = 'meta-llama/llama-3.1-8b-instruct:free';
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
/// Throw [AiFailure] jujur.
Future<String> orChatRaw({
  required String apiKey,
  required String prompt,
  String? model,
  http.Client? client,
}) async {
  if (apiKey.trim().isEmpty || prompt.trim().isEmpty) {
    throw const AiFailure('empty', '[OpenRouter] kunci/prompt kosong');
  }
  final name = (model ?? '').trim().isNotEmpty ? model!.trim() : aiOrModel;
  final httpClient = client ?? http.Client();
  final owned = client == null;
  try {
    for (var attempt = 0; attempt < 2; attempt++) {
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
          throw const AiFailure('denied', '[OpenRouter] kunci ditolak');
        }
        if (res.statusCode == 429) {
          var snippet = res.body;
          if (snippet.length > 300) snippet = snippet.substring(0, 300);
          throw AiFailure('quota', '[OpenRouter] $snippet');
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          if (res.statusCode >= 500 && attempt == 0) continue;
          throw AiFailure('server', '[OpenRouter] HTTP ${res.statusCode}');
        }
        dynamic body;
        try {
          body = jsonDecode(res.body);
        } catch (_) {
          throw const AiFailure('server', '[OpenRouter] body bukan JSON');
        }
        final content = openAiContentFromBody(body);
        if (content == null) {
          if (attempt == 0) continue;
          throw const AiFailure('empty', '[OpenRouter]');
        }
        return content;
      } on AiFailure {
        rethrow;
      } on TimeoutException catch (e) {
        if (attempt == 0) continue;
        throw AiFailure('timeout', '[OpenRouter] $e');
      } catch (e) {
        if (attempt == 0) continue;
        throw AiFailure('network', '[OpenRouter] $e');
      }
    }
    throw const AiFailure('network', '[OpenRouter] percobaan habis');
  } finally {
    if (owned) httpClient.close();
  }
}
