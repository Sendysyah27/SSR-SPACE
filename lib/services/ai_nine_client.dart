// Klien AI 9router lokal (OpenAI-compatible) — provider 'nine'.
//
// 9router (https://github.com/9router) di HP user berjalan di
// http://127.0.0.1:20128 dan menyediakan endpoint kompatibel OpenAI:
//   GET  /v1/models           (tanpa key)
//   POST /v1/chat/completions (WAJIB Authorization: Bearer <key>)
//
// Jalur ini menggantikan Edge Function `mang-ai-chat` untuk chat,
// asisten, insight laporan, DAN scan struk (vision) — semuanya lewat
// model lokal milik user. Karena tidak ada EF, dua pekerjaan yang di
// server dilakukan EF dikerjakan di sini:
//   1. prompt receipt dirakit lokal (receiptSystemPrompt, kategori app)
//   2. keluaran model dinormalisasi jadi JSON ketat (normalizeReceiptContract)
// Port murni keduanya ada di `nine_prompts.dart`.
//
// Kunci API disimpan di Keystore (ai_key_store: ssr_nine_api_key),
// base + model di prefs. Kunci TIDAK PERNAH di-log.
// Throw [AiFailure] jujur (kode: empty | timeout | denied | server).

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_key_store.dart';
import 'ai_pii.dart';
import 'ai_soul.dart';
import 'firebase_ai_parser.dart' show AiFailure;
import 'nine_prompts.dart';

/// Label provider untuk tracking riwayat/telemetri.
const nineProviderName = '9router-lokal';

const nineTimeout = Duration(seconds: 60);
const nineVisionTimeout = Duration(seconds: 120);

String _snip(String s, [int max = 200]) =>
    s.length <= max ? s : s.substring(0, max);

/// Pesan error ringkas dari body 9router (`{error:{message}}` /
/// `{message}` / `{error:"..."}`), fallback ke body mentah.
String _nineError(Object? body) {
  if (body is Map) {
    final err = body['error'];
    if (err is Map && err['message'] != null) return err['message'].toString();
    if (err is String && err.isNotEmpty) return err;
    if (body['message'] != null) return body['message'].toString();
  }
  if (body is String && body.isNotEmpty) return body;
  return '';
}

/// Isi `choices[0].message.content` yang bisa String atau list part.
String _contentText(Object? content) {
  if (content is String) return content;
  if (content is List) {
    final buf = StringBuffer();
    for (final p in content) {
      if (p is Map && p['text'] is String) buf.write(p['text'] as String);
    }
    return buf.toString();
  }
  return '';
}

/// Chat lewat 9router lokal. [kind]: 'chat' | 'receipt' | 'quick'.
/// kind 'receipt' -> system prompt receipt dirakit dari [categories]
/// (default daftar bawaan), keluaran dinormalisasi ke JSON ketat
/// `{merchant,date,total,category,items[]}` — kontrak yang sama dengan
/// EF mang-ai-chat, jadi `parseReceiptScanJson` klien tak berubah.
Future<({String text, String provider})> aiChatViaNine(
  String prompt, {
  List<int>? imageBytes,
  String? mimeType,
  List<({bool mine, String text})>? history,
  String? dataContext,
  String? system,
  String kind = 'chat',
  List<String>? categories,
  Duration? timeout,
}) async {
  if (prompt.trim().isEmpty) {
    throw const AiFailure('empty', 'prompt kosong');
  }
  final key = await readNineKey();
  if (key == null) {
    throw const AiFailure(
      'denied',
      '[9router] Belum ada API key 9router. Buka Provider AI untuk mengisi.',
    );
  }
  final base = await nineBaseUrl();
  final model = await nineModel();
  final hasImage = imageBytes != null && imageBytes.isNotEmpty;

  final isReceipt = kind == 'receipt';
  final cats = isReceipt
      ? (categories == null || categories.isEmpty
            ? defaultReceiptCategories
            : categories)
      : const <String>[];

  final sys = isReceipt
      ? receiptSystemPrompt(cats)
      : ((system != null && system.trim().isNotEmpty) ? system : aiSoul);

  final convo = (history == null || history.isEmpty)
      ? ''
      : '${chatHistoryBlock(history)}\n';
  final data = (dataContext ?? '').trim().isNotEmpty
      ? '${dataContext!.trim()}\n'
      : '';
  final masked = maskPii('$convo$data$prompt');

  final Object userContent = hasImage
      ? <Map<String, dynamic>>[
          {'type': 'text', 'text': masked},
          {
            'type': 'image_url',
            'image_url': {
              'url':
                  'data:${mimeType ?? 'image/jpeg'};base64,'
                  '${base64Encode(imageBytes)}',
            },
          },
        ]
      : masked;

  final body = <String, dynamic>{
    'model': model,
    'messages': <Map<String, dynamic>>[
      {'role': 'system', 'content': sys},
      {'role': 'user', 'content': userContent},
    ],
    'stream': false,
  };

  final effectiveTimeout =
      timeout ?? (hasImage ? nineVisionTimeout : nineTimeout);
  final uri = Uri.parse('$base/v1/chat/completions');
  try {
    final res = await http
        .post(
          uri,
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode(body),
        )
        .timeout(effectiveTimeout);

    Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      decoded = res.body;
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const AiFailure(
        'denied',
        '[9router] API key ditolak. Periksa key di Provider AI.',
      );
    }
    if (res.statusCode == 429) {
      throw const AiFailure(
        'server',
        '[9router] Limit model tercapai, coba lagi nanti.',
      );
    }
    if (res.statusCode >= 400) {
      final msg = _nineError(decoded);
      throw AiFailure(
        'server',
        '[9router] HTTP ${res.statusCode}'
            '${msg.isEmpty ? '' : ': ${_snip(msg)}'}',
      );
    }
    if (decoded is! Map) {
      throw const AiFailure('server', '[9router] body bukan JSON.');
    }
    final choices = decoded['choices'];
    String text = '';
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final msg = first['message'];
        if (msg is Map) text = _contentText(msg['content']);
      }
    }
    if (text.trim().isEmpty) {
      throw const AiFailure('server', '[9router] AI tidak mengembalikan teks.');
    }
    if (isReceipt) {
      text = normalizeReceiptContract(text, cats);
    } else {
      text = normalizeChatContract(text);
    }
    return (text: text, provider: nineProviderName);
  } on AiFailure {
    rethrow;
  } on TimeoutException {
    throw const AiFailure('timeout', '[9router] Timeout.');
  } on http.ClientException catch (e) {
    throw AiFailure(
      'server',
      '[9router] Tidak bisa menghubungi $base (${_snip(e.message)}).',
    );
  } catch (e) {
    throw AiFailure('server', '[9router] ${_snip(e.toString())}');
  }
}
