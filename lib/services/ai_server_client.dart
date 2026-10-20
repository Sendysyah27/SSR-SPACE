import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/org_prefs.dart';
import 'ai_key_store.dart';
import 'ai_soul.dart';
import 'firebase_ai_parser.dart';
import 'supabase_config.dart';

// Mang AI via SERVER (jalur default sejak 2.82.13+280): app memanggil
// Edge Function `mang-ai-chat` (Supabase) — JWT user + cek anggota org +
// kuota AI per plan (check_quota 'ai') ditegakkan server-side, lalu
// request diteruskan ke AI Gateway (Cloudflare Worker) yang membentuk
// request ala OpenCode CLI ke free-tier OpenCode. Menggantikan jalur
// OpenCode lokal (Termux) agar Mang AI bisa dipakai SEMUA user, bukan
// cuma device yang menjalankan opencode serve sendiri.
//
// Komposisi prompt PERSIS seperti jalur lama di aiChatViaCli:
// history block (chatHistoryBlock) + dataContext + prompt, lalu masking
// nomor panjang (>= 10 digit). System: dari pemanggil bila ada; bila
// tidak, aiSoul — dulu system default datang dari native Kotlin
// (DEFAULT_SYSTEM), di jalur server soul dikirim eksplisit sebagai
// message 'system'. Nilai timeout disamakan dengan ai_cli_client
// (cliTimeout 30 dtk / visionScanTimeout 120 dtk); file ini TIDAK
// mengimpor ai_cli_client agar tidak ada siklus impor (ai_cli_client
// mengimpor file ini untuk delegasi).

/// Nama provider untuk tracking.
const serverProviderName = 'mang-ai-server';

const _serverTimeout = Duration(seconds: 30);
const _serverVisionTimeout = Duration(seconds: 120);

/// Mask nomor panjang (>= 10 digit) untuk keamanan (sama seperti
/// _maskLongNumbers di ai_cli_client.dart).
String _maskLongNumbers(String text) =>
    text.replaceAll(RegExp(r'\d{10,}'), '[MASKED]');

String _snip(String s, [int max = 200]) =>
    s.length <= max ? s : s.substring(0, max);

/// Ekstrak pesan error ringkas dari detail FunctionException
/// (Map {error: ...} / String JSON / String polos).
String _fnDetail(Object? details) {
  if (details is Map && details['error'] != null) {
    return details['error'].toString();
  }
  if (details is String && details.isNotEmpty) {
    try {
      final d = jsonDecode(details);
      if (d is Map && d['error'] != null) return d['error'].toString();
    } catch (_) {}
    return details;
  }
  return '';
}

/// Chat AI lewat Edge Function `mang-ai-chat`.
/// [kind]: 'chat' | 'receipt' | 'quick' (dicatat server sebagai
/// pemakaian kuota). Gambar selalu dikirim sebagai part image_url
/// data-URI dan dipasangkan model vision di body.
/// Throw [AiFailure] jujur (kode: empty | timeout | denied | server).
Future<({String text, String provider})> aiChatViaServer(
  String prompt, {
  List<int>? imageBytes,
  String? mimeType,
  List<({bool mine, String text})>? history,
  String? dataContext,
  String? system,
  String kind = 'chat',
  Duration? timeout,
}) async {
  if (prompt.trim().isEmpty) {
    throw const AiFailure('empty', 'prompt kosong');
  }
  final hasImage = imageBytes != null && imageBytes.isNotEmpty;

  final convo = (history == null || history.isEmpty)
      ? ''
      : '${chatHistoryBlock(history)}\n';
  final data =
      (dataContext ?? '').trim().isNotEmpty ? '${dataContext!.trim()}\n' : '';
  final masked = _maskLongNumbers('$convo$data$prompt');

  final orgId = await activeOrgId();
  if (orgId.isEmpty) {
    throw const AiFailure('denied', '[AI] Workspace aktif tidak ditemukan.');
  }

  final sys = (system != null && system.trim().isNotEmpty) ? system : aiSoul;
  final Object userContent = hasImage
      ? <Map<String, dynamic>>[
          {'type': 'text', 'text': masked},
          {
            'type': 'image_url',
            'image_url': {
              'url':
                  'data:${mimeType ?? 'image/jpeg'};base64,${base64Encode(imageBytes)}',
            },
          },
        ]
      : masked;
  final messages = <Map<String, dynamic>>[
    {'role': 'system', 'content': sys},
    {'role': 'user', 'content': userContent},
  ];

  final effectiveTimeout =
      timeout ?? (hasImage ? _serverVisionTimeout : _serverTimeout);
  try {
    final res = await SupabaseConfig.client.functions
        .invoke('mang-ai-chat', body: {
          'org_id': orgId,
          'kind': kind,
          'messages': messages,
          if (hasImage) 'model': 'nemotron-3.5-super-vl-free',
        })
        .timeout(effectiveTimeout);
    final d = res.data;
    if (d is Map) {
      final text = d['text'];
      if (text is String && text.trim().isNotEmpty) {
        return (text: text, provider: serverProviderName);
      }
    }
    throw const AiFailure('server', '[AI] response kosong');
  } on FunctionException catch (e) {
    final detail = _fnDetail(e.details);
    final blob = '${e.details ?? ''} $detail';
    if (e.status == 403 || blob.contains('QUOTA_EXCEEDED')) {
      await noteQuotaHit();
      throw const AiFailure('server',
          '[AI] Kuota AI bulan ini habis. Upgrade Pro untuk tanpa batas.');
    }
    if (e.status == 401) {
      throw const AiFailure('denied', '[AI] Sesi login berakhir, masuk lagi.');
    }
    throw AiFailure('server',
        '[AI] ${_snip(detail.isNotEmpty ? detail : 'server error (${e.status})')}');
  } on TimeoutException {
    throw const AiFailure('timeout', '[AI] Timeout.');
  } catch (e) {
    if (e is AiFailure) rethrow;
    throw AiFailure('server', '[AI] ${_snip(e.toString())}');
  }
}
