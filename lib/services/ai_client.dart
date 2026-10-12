import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'ai_draft.dart';

// AI fallback parser struk via OpenCode Zen (OpenAI-compatible).
// Rule-based tetap utama; fungsi ini hanya dipanggil bila rule tak
// confident. Tanpa upload foto (teks OCR saja), timeout 30 dtk,
// retry 1x khusus timeout/jaringan/server-5xx. Selain itu gagal jujur.
const aiZenEndpoint = 'https://opencode.ai/zen/v1/chat/completions';
const aiZenModel = 'kimi-k2.5-free';
const aiTimeout = Duration(seconds: 30);

class AiFailure implements Exception {
  // timeout | network | denied | server | empty
  final String code;
  const AiFailure(this.code);
}

/// Teks OCR -> [AiDraft]. Null = AI tak bisa dipakai (pemanggil fallback
/// manual). Melempar [AiFailure] dengan sebab jujur.
Future<AiDraft?> parseReceiptAi({
  required String apiKey,
  required String ocrText,
  http.Client? client,
}) async {
  if (apiKey.trim().isEmpty || ocrText.trim().isEmpty) return null;
  final httpClient = client ?? http.Client();
  final owned = client == null;
  try {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await httpClient
            .post(
              Uri.parse(aiZenEndpoint),
              headers: {
                'Authorization': 'Bearer ${apiKey.trim()}',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': aiZenModel,
                'temperature': 0.1,
                'max_tokens': 1500,
                'messages': [
                  {
                    'role': 'system',
                    'content': 'Kamu pengurai struk belanja. Jawab hanya '
                        'dengan objek JSON valid, tanpa markdown.',
                  },
                  {'role': 'user', 'content': aiReceiptPrompt(ocrText)},
                ],
              }),
            )
            .timeout(aiTimeout);
        if (res.statusCode == 401 || res.statusCode == 403) {
          throw const AiFailure('denied');
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          if (res.statusCode >= 500 && attempt == 0) continue;
          throw const AiFailure('server');
        }
        dynamic body;
        try {
          body = jsonDecode(res.body);
        } catch (_) {
          throw const AiFailure('server');
        }
        final choices = body is Map ? body['choices'] : null;
        final content = choices is List && choices.isNotEmpty
            ? (choices.first is Map
                ? (choices.first['message'] is Map
                    ? choices.first['message']['content']
                    : null)
                : null)
            : null;
        if (content is! String || content.trim().isEmpty) {
          throw const AiFailure('empty');
        }
        final draft = parseAiDraft(content);
        if (draft == null && attempt == 0) continue;
        return draft;
      } on AiFailure {
        rethrow;
      } on TimeoutException {
        if (attempt == 0) continue;
        throw const AiFailure('timeout');
      } catch (_) {
        if (attempt == 0) continue;
        throw const AiFailure('network');
      }
    }
    throw const AiFailure('network');
  } finally {
    if (owned) httpClient.close();
  }
}
