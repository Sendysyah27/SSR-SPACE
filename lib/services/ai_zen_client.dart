import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'ai_draft.dart';
import 'firebase_ai_parser.dart';

// OpenCode Zen LANGSUNG dari app (tanpa proxy VPS).
// Primer: POST /v1/responses untuk muse-spark-1.3-contributor-free.
// Cadangan: POST /v1/chat/completions untuk model free lain.
// Header memimik CLI OpenCode; API key user via Bearer.
// stream:true → respons SSE (parse manual); bila server jawab JSON
// biasa, parsing JSON dipakai. Prefix [Zen] untuk diagnosis.
// Helper murni (ID sesi/request, header, tools, SSE) tinggal di
// firebase_ai_parser.dart agar testable via `dart`.
const zenResponsesEndpoint = 'https://opencode.ai/zen/v1/responses';
const zenChatEndpoint = 'https://opencode.ai/zen/v1/chat/completions';
const zenModelSpark = 'muse-spark-1.3-contributor-free';
const zenModelFree = 'kimi-k2.5-free';
const aiZenTimeout = Duration(seconds: 60);

/// POST Zen + baca respons (SSE atau JSON). Return teks gabungan.
/// Throw [AiFailure] jujur (tag = label diagnosis, mis. [Zen]).
/// [apiKey] kosong = ANONIM (tanpa header Authorization): free tier
/// bisa jalan tanpa kunci. Kunci ditolak (401/403) -> coba anonim
/// sekali sebelum menyerah.
Future<String> _zenPost({
  String? apiKey,
  required String endpoint,
  required Map<String, Object?> Function() bodyOf,
  required String tag,
  required String session,
  http.Client? client,
}) async {
  final key = (apiKey ?? '').trim();
  // Urutan coba: kunci dulu (bila ada), lalu anonim.
  final modes = key.isNotEmpty ? [key, null] : [null];
  final httpClient = client ?? http.Client();
  final owned = client == null;
  AiFailure? lastDenied;
  try {
    for (final mode in modes) {
      try {
        final req = http.Request('POST', Uri.parse(endpoint));
        req.headers.addAll(zenHeaders(session, zenRequestId()));
        if (mode != null) {
          req.headers['Authorization'] = 'Bearer $mode';
        }
        req.body = jsonEncode(bodyOf());
        final streamed =
            await httpClient.send(req).timeout(aiZenTimeout);
        if (streamed.statusCode == 401 || streamed.statusCode == 403) {
          final snippet = await _readSnippet(streamed);
          lastDenied = AiFailure(
              'denied', '[$tag] kunci ditolak $snippet');
          debugPrint('zen ${mode == null ? 'anonim' : 'kunci'} ditolak, '
              '${mode == null ? 'menyerah' : 'coba anonim'}...');
          continue;
        }
        if (streamed.statusCode == 429) {
          final snippet = await _readSnippet(streamed);
          throw AiFailure('quota', '[$tag] $snippet');
        }
        if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
          final snippet = await _readSnippet(streamed);
          throw AiFailure(
              'server', '[$tag] HTTP ${streamed.statusCode} $snippet');
        }
        return await _readText(streamed, tag);
      } on AiFailure {
        rethrow;
      } on TimeoutException catch (e) {
        throw AiFailure('timeout', '[$tag] $e');
      } catch (e) {
        throw AiFailure('network', '[$tag] $e');
      }
    }
    throw lastDenied ?? const AiFailure('denied', '[$tag] ditolak');
  } finally {
    if (owned) httpClient.close();
  }
}

/// Baca teks gabungan dari respons sukses (SSE atau JSON).
Future<String> _readText(http.StreamedResponse streamed, String tag) async {
  final ctype = streamed.headers['content-type'] ?? '';
  String text;
  if (ctype.contains('text/event-stream')) {
    final lines = <String>[];
    await for (final chunk in streamed.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final t = chunk.trim();
      if (t.startsWith('data:')) {
        lines.add(t.substring(5).trim());
      } else if (t.isNotEmpty && !t.startsWith(':')) {
        lines.add(t);
      }
    }
    text = zenSseText(lines);
  } else {
    final raw = await streamed.stream.transform(utf8.decoder).join();
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw AiFailure('server', '[$tag] body bukan JSON');
    }
    if (decoded is Map &&
        decoded['choices'] is List &&
        (decoded['choices'] as List).isNotEmpty) {
      text = zenSseText([
        jsonEncode({
          'choices': decoded['choices'],
        })
      ]);
    } else {
      text = decoded is String ? decoded : '';
    }
  }
  if (text.trim().isEmpty) throw AiFailure('empty', '[$tag] tanpa teks');
  return text;
}

/// Baca ≤300 char pertama stream (untuk cuplikan error).
Future<String> _readSnippet(http.StreamedResponse res) async {
  try {
    final s =
        await res.stream.transform(utf8.decoder).join().timeout(
              const Duration(seconds: 10),
            );
    return s.length <= 300 ? s : s.substring(0, 300);
  } catch (_) {
    return '';
  }
}

/// Teks OCR -> [AiDraft] via Zen langsung. Null = tak bisa dipakai
/// (pemanggil lanjut ke Firebase). Melempar [AiFailure] jujur.
/// Tanpa kunci = ANONIM (free tier bisa jalan tanpa key).
Future<AiDraft?> parseReceiptZen({
  String? apiKey,
  required String ocrText,
  http.Client? client,
}) async {
  if (ocrText.trim().isEmpty) return null;
  final session = zenSessionId();
  try {
    final text = await _zenPost(
      apiKey: apiKey,
      endpoint: zenResponsesEndpoint,
      bodyOf: () => {
        'model': zenModelSpark,
        'input': aiReceiptPrompt(ocrText),
        'stream': true,
        'tool_choice': 'auto',
        'store': false,
        'tools': zenTools(),
      },
      tag: 'Zen:$zenModelSpark',
      session: session,
      client: client,
    );
    return parseAiDraft(text);
  } on AiFailure catch (e) {
    if (e.code == 'denied' || e.code == 'quota') rethrow;
  }
  // 2) Cadangan: model free via /chat/completions.
  // (_zenPost hanya melempar AiFailure → teruskan apa adanya.)
  final text = await _zenPost(
    apiKey: apiKey,
    endpoint: zenChatEndpoint,
    bodyOf: () => {
      'model': zenModelFree,
      'stream': true,
      'temperature': 0.1,
      'max_tokens': 1500,
      'messages': [
        {'role': 'user', 'content': aiReceiptPrompt(ocrText)},
      ],
      'tools': zenTools(),
    },
    tag: 'Zen:$zenModelFree',
    session: session,
    client: client,
  );
  return parseAiDraft(text);
}

/// Chat mentah ke Zen langsung (untuk Tes AI): prompt bebas ->
/// (teks, provider). Throw [AiFailure] jujur. Tanpa kunci = ANONIM.
Future<({String text, String provider})> zenChatRaw({
  String? apiKey,
  required String prompt,
  http.Client? client,
}) async {
  if (prompt.trim().isEmpty) {
    throw const AiFailure('empty', '[Zen] prompt kosong');
  }
  final session = zenSessionId();
  try {
    final text = await _zenPost(
      apiKey: apiKey,
      endpoint: zenResponsesEndpoint,
      bodyOf: () => {
        'model': zenModelSpark,
        'input': prompt,
        'stream': true,
        'tool_choice': 'auto',
        'store': false,
        'tools': zenTools(),
      },
      tag: 'Zen:$zenModelSpark',
      session: session,
      client: client,
    );
    return (text: text, provider: zenModelSpark);
  } on AiFailure catch (e) {
    if (e.code == 'denied' || e.code == 'quota') rethrow;
    // Cadangan chat/completions, provider = model cadangan.
    final text = await _zenPost(
      apiKey: apiKey,
      endpoint: zenChatEndpoint,
      bodyOf: () => {
        'model': zenModelFree,
        'stream': true,
        'temperature': 0.1,
        'max_tokens': 1500,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'tools': zenTools(),
      },
      tag: 'Zen:$zenModelFree',
      session: session,
      client: client,
    );
    return (text: text, provider: zenModelFree);
  }
}
