import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

import 'ai_key_store.dart';
import 'ai_openrouter_client.dart';
import 'ai_soul.dart';
import 'ai_zen_client.dart';
import 'firebase_ai_parser.dart';
import 'receipt_scan_service.dart';

// Daftar fallback model: utama dulu, lalu stabil cadangan.
// SENGAJA tanpa gemini-2.0/1.5-flash: keduanya mati 2026
// (request = 404 pasti). Cadangan = 3.5-flash (stabil ≥2027-05-19).
const firebaseAiModels = ['gemini-flash-latest', 'gemini-3.5-flash'];
const firebaseAiModel = 'gemini-flash-latest';

// Kunci API Android dari google-services.json (disuntik CI via
// dart-define GOOGLE_API_KEY; kosong = tanpa REST fallback).
// Dipakai HANYA untuk Plan B REST langsung ke Gemini Developer API.
const googleApiKey = String.fromEnvironment('GOOGLE_API_KEY',
    defaultValue: '');

const _restTimeout = Duration(seconds: 30);
const _reachTimeout = Duration(seconds: 10);
const _reachUrl = 'https://generativelanguage.googleapis.com';

/// GET root server Google AI (10 dtk). Status berapa pun = bisa reach;
/// timeout/DNS/TLS = buntu. Tak pernah throw (lapor string selalu ada).
Future<String> checkGoogleAiReachability() async {
  final client = http.Client();
  try {
    final res = await client
        .get(Uri.parse(_reachUrl))
        .timeout(_reachTimeout);
    debugPrint('firebase ai reach: HTTP ${res.statusCode}');
    return reachReport(status: res.statusCode);
  } catch (e) {
    debugPrint('firebase ai reach gagal: $e');
    return reachReport(error: '$e');
  } finally {
    client.close();
  }
}

/// Urutan coba model REST: alias terbaru dulu, lalu stabil pin.
/// SENGAJA tanpa gemini-2.0/1.5-flash: keduanya mati 2026
/// (request = 404 pasti, bukan fallback).
const geminiRestModels = ['gemini-flash-latest', 'gemini-3.5-flash'];

/// Plan B: POST langsung ke Gemini Developer API bila SDK hang.
/// Model sibuk (503/penuh, bukan kuota) → jeda 3 dtk + model berikut.
/// Kuota → throw 'quota' langsung (tanpa rotasi, pool sama).
/// HTTP non-200 lain / body rusak / 200-tanpa-teks juga throw
/// (server/empty) — jangan disamarkan jadi null/"kosong".
/// Format kunci APAPUN dikirim apa adanya (tak ada validasi prefix).
/// [apiKey]: kunci user (primer); kosong = kunci build; dua-dua
/// kosong = null langsung (tanpa request).
/// [onModel]: dipanggil dengan nama model yang menjawab sukses.
Future<String?> restGenerate(String prompt,
    {String? model,
    String? apiKey,
    http.Client? client,
    void Function(String model)? onModel,
    List<int>? imageBytes,
    String? mimeType}) async {
  final key =
      (apiKey ?? '').trim().isNotEmpty ? apiKey!.trim() : googleApiKey;
  if (key.isEmpty) return null;
  final names = model != null ? [model] : geminiRestModels;
  final httpClient = client ?? http.Client();
  final owned = client == null;
  String? lastDetail;
  try {
    for (var mi = 0; mi < names.length; mi++) {
      final name = names[mi];
      try {
        final parts = <Map<String, Object?>>[
          {'text': prompt}
        ];
        if (imageBytes != null && imageBytes.isNotEmpty) {
          parts.add({
            'inline_data': {
              'mime_type': (mimeType ?? '').isNotEmpty
                  ? mimeType!
                  : 'image/jpeg',
              'data': base64Encode(imageBytes),
            }
          });
        }
        final res = await httpClient
            .post(
              Uri.parse(
                  'https://generativelanguage.googleapis.com/v1beta/models/$name:generateContent'),
              headers: {
                'x-goog-api-key': key,
                'Content-Type': 'application/json',
              },
              body: imageBytes != null && imageBytes.isNotEmpty
                  ? jsonEncode({
                      'contents': [
                        {'parts': parts}
                      ],
                    })
                  : jsonEncode(restPromptBody(prompt)),
            )
            .timeout(_restTimeout);
        debugPrint('firebase ai rest $name status ${res.statusCode}');
        if (res.statusCode != 200) {
          var snippet = res.body;
          if (snippet.length > 300) snippet = snippet.substring(0, 300);
          debugPrint('firebase ai rest $name gagal ${res.statusCode}: $snippet');
          if (isQuotaMessage(snippet)) {
            await noteQuotaHit();
            throw AiFailure('quota', snippet);
          }
          if (res.statusCode == 503 || isBusyMessage(snippet)) {
            lastDetail = 'HTTP ${res.statusCode} $snippet';
            if (mi < names.length - 1) {
              debugPrint('firebase ai rest sibuk, jeda 3 dtk ganti model...');
              await Future.delayed(const Duration(seconds: 3));
            }
            continue;
          }
          throw AiFailure(
              'server', '[Gemini] HTTP ${res.statusCode} $snippet');
        }
        dynamic body;
        try {
          body = jsonDecode(res.body);
        } catch (_) {
          throw const AiFailure('server', '[Gemini] body bukan JSON');
        }
        final text = parseRestText(body);
        if (text == null || text.trim().isEmpty) {
          throw const AiFailure('empty', '[Gemini] 200 tanpa teks');
        }
        onModel?.call(name);
        return text;
      } on AiFailure {
        rethrow;
      } on TimeoutException {
        debugPrint('firebase ai rest $name timeout');
        return null;
      } catch (e) {
        debugPrint('firebase ai rest $name gagal: $e');
        return null;
      }
    }
    throw AiFailure('server', '[Gemini] semua model sibuk $lastDetail');
  } finally {
    if (owned) httpClient.close();
  }
}

// Sakelar AI Parser (prefs biasa, default ON — tanpa kunci = langsung
// jalan bila login Google). Tanpa prefs (error) = ON (fail-open).
const _kAiEnabled = 'ai_enabled';

// Cap waktu terakhir kuota habis (ISO, prefs biasa). Dibaca Settings
// untuk info jujur "terakhir kehabisan".
const _kQuotaHit = 'ai_quota_hit';

Future<void> noteQuotaHit() async {
  try {
    await (await SharedPreferences.getInstance())
        .setString(_kQuotaHit, DateTime.now().toIso8601String());
  } catch (_) {}
}

Future<DateTime?> lastQuotaHit() async {
  try {
    final v =
        (await SharedPreferences.getInstance()).getString(_kQuotaHit);
    if (v == null || v.isEmpty) return null;
    return DateTime.tryParse(v);
  } catch (_) {
    return null;
  }
}

Future<bool> aiEnabled() async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kAiEnabled) ?? true;
  } catch (_) {
    return true;
  }
}

Future<void> setAiEnabled(bool v) async {
  try {
    await (await SharedPreferences.getInstance()).setBool(_kAiEnabled, v);
  } catch (_) {}
}

// Sakelar per provider (default ON semua). Nama: gemini/openrouter/
// firebase. Dipakai sheet + Tes AI agar user bisa matikan per jalur.
const aiProvGemini = 'gemini';
const aiProvOr = 'openrouter';
const aiProvZen = 'zen';
const aiProvFb = 'firebase';

String _provKey(String name) => 'ai_prov_$name';

Future<bool> aiProviderOn(String name) async {
  try {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_provKey(name)) ?? true;
  } catch (_) {
    return true;
  }
}

Future<void> setAiProviderOn(String name, bool v) async {
  try {
    await (await SharedPreferences.getInstance())
        .setBool(_provKey(name), v);
  } catch (_) {}
}

/// Pastikan ada sesi Firebase Auth (syarat AI parser), untuk SEMUA cara
/// login Supabase — bukan cuma Google. Urutan: sesi ada → true;
/// ada idToken Google → link credential; selain itu → anonim.
/// Tak pernah throw (false = AI mati, app tetap jalan).
/// Catatan: anonim butuh provider Anonymous ON di Firebase console;
/// bila mati = false (fail-open, bukan crash).
Future<bool> ensureFirebaseSession({
  String? idToken,
  String? accessToken,
}) async {
  try {
    if (FirebaseAuth.instance.currentUser != null) return true;
    if (idToken != null && idToken.isNotEmpty) {
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: accessToken,
        ),
      );
    } else {
      await FirebaseAuth.instance.signInAnonymously();
    }
    return FirebaseAuth.instance.currentUser != null;
  } catch (_) {
    return false;
  }
}

/// Bangun [AiGenerate] dari model Firebase, atau null bila AI tak bisa
/// dipakai (Firebase belum init / tanpa sesi Firebase / error apa
/// pun). Tak pernah throw — pemanggil diam bila null.
Future<AiGenerate?> firebaseAiGenerate() async {
  try {
    if (FirebaseAuth.instance.currentUser == null) return null;
    return (prompt) async {
      String? lastDetail;
      for (var mi = 0; mi < firebaseAiModels.length; mi++) {
        final name = firebaseAiModels[mi];
        try {
          debugPrint('firebase ai sdk mulai ($name)...');
          final model = FirebaseAI.googleAI().generativeModel(model: name);
          // Timeout di DALAM closure agar on TimeoutException di bawah
          // (→ REST) yang menang, bukan timeout luar parser.
          final res = await model
              .generateContent([Content.text(prompt)])
              .timeout(firebaseAiTimeout);
          debugPrint('firebase ai sdk selesai ($name).');
          return res.text;
        } on TimeoutException {
          // SDK hang: Plan B REST langsung (30 dtk). Sukses = pakai;
          // gagal = vonis timeout jujur (tanpa retry ganda pemanggil).
          debugPrint('firebase ai sdk hang ($name), coba REST...');
          final t = await restGenerate(prompt, model: name);
          if (t != null && t.trim().isNotEmpty) return t;
          throw const AiFailure('timeout', 'sdk hang + rest gagal');
        } catch (e) {
          // Log lengkap untuk diagnosis via `adb logcat` (tak diupload).
          debugPrint('firebase ai gagal ($name): $e');
          final m = e.toString().toLowerCase();
          if (m.contains('app check') ||
              m.contains('appcheck') ||
              m.contains('app_check') ||
              m.contains('integrity')) {
            throw AiAppCheck(e.toString());
          }
          if (m.contains('permission-denied') ||
              m.contains('unauthenticated') ||
              m.contains('403') ||
              m.contains('api key')) {
            throw AiDenied(e.toString());
          }
          if (isQuotaMessage(m)) {
            // Kuota habis: retry/rotasi PERCUMA (batas per project).
            // Catat waktu + vonis langsung dengan pesan asli.
            await noteQuotaHit();
            throw AiFailure('quota', e.toString());
          }
          if (isBusyMessage(m)) {
            // 500/quota/penuh: jeda 3 dtk lalu coba model cadangan.
            lastDetail = e.toString();
            if (mi < firebaseAiModels.length - 1) {
              debugPrint('firebase ai sibuk, jeda 3 dtk ganti model...');
              await Future.delayed(const Duration(seconds: 3));
            }
            continue;
          }
          rethrow;
        }
      }
      throw AiFailure('server', lastDetail ?? 'semua model sibuk');
    };
  } catch (_) {
    return null;
  }
}

/// Chat bebas dengan AI (room chat): prompt apa saja -> (teks, provider).
/// Urutan sama seperti scan: Gemini -> OpenRouter -> Zen -> Firebase,
/// hormati toggle per provider. Pertama sukses menang; semua gagal =
/// throw error terakhir. Tak kirim foto/riwayat (prompt saja).
/// Tanya model Firebase langsung dengan GAMBAR (multimodal).
/// Return teks atau null; throw [AiFailure] jujur (quota/denied/server).
Future<String?> firebaseVisionAsk({
  required List<int> bytes,
  required String prompt,
  String? mimeType,
}) async {
  try {
    if (FirebaseAuth.instance.currentUser == null) return null;
    final model = FirebaseAI.googleAI().generativeModel(
      model: firebaseAiModel,
    );
    final res = await model
        .generateContent([
          Content.multi([
            TextPart(prompt),
            InlineDataPart(
              (mimeType ?? '').isNotEmpty ? mimeType! : 'image/jpeg',
              Uint8List.fromList(bytes),
            ),
          ])
        ])
        .timeout(const Duration(seconds: 60));
    return res.text;
  } catch (e) {
    final m = e.toString().toLowerCase();
    if (m.contains('app check') ||
        m.contains('appcheck') ||
        m.contains('app_check') ||
        m.contains('integrity')) {
      throw AiAppCheck(e.toString());
    }
    if (m.contains('permission-denied') ||
        m.contains('unauthenticated') ||
        m.contains('403') ||
        m.contains('api key')) {
      throw AiDenied(e.toString());
    }
    if (isQuotaMessage(m)) throw AiFailure('quota', e.toString());
    if (isBusyMessage(m)) throw AiFailure('server', e.toString());
    rethrow;
  }
}

Future<({String text, String provider})> aiChat(
  String prompt, {
  List<int>? imageBytes,
  String? mimeType,
  List<({bool mine, String text})>? history,
}) async {
  if (prompt.trim().isEmpty) {
    throw const AiFailure('empty', 'prompt kosong');
  }
  // Riwayat sesi sebagai konteks (AI jadi ingat percakapan).
  final convo = (history == null || history.isEmpty)
      ? ''
      : '${chatHistoryBlock(history)}\n';
  prompt = '$convo$prompt';
  final hasImage = imageBytes != null && imageBytes.isNotEmpty;
  AiFailure? last;
  void note(AiFailure e) {
    last = e;
    if (e.code == 'quota') unawaited(noteQuotaHit());
  }
  // Prompt efektif: bila gambar dan vision gagal/tak tersedia, tempel
  // hasil OCR lokal agar provider text-only tetap bisa baca gambar.
  var effectivePrompt = prompt;
  var viaOcr = false;

  if (await aiProviderOn(aiProvGemini)) {
    final k = await readGeminiKey();
    if (k != null) {
      try {
        String? used;
        final t = await restGenerate(prompt,
                apiKey: k,
                onModel: (m) => used = m,
                imageBytes: imageBytes,
                mimeType: mimeType)
            .timeout(const Duration(seconds: 60));
        if (t != null && t.trim().isNotEmpty) {
          return (
            text: t,
            provider: 'Gemini${used == null ? '' : ': $used'}'
          );
        }
      } on AiFailure catch (e) {
        note(e);
      } catch (e) {
        note(AiFailure('network', '[Gemini] $e'));
      }
    }
  }
  // OpenRouter & Zen text-only: bila ada gambar, OCR-kan lokal dulu
  // (jangan tampilkan error butuh-Gemini selama OCR bisa jalan).
  List<int>? imgBytes;
  if (hasImage) imgBytes = imageBytes;
  if (imgBytes != null) {
    final orOn = await aiProviderOn(aiProvOr);
    final zenOn = await aiProviderOn(aiProvZen);
    final orKey = await readOrKey();
    if ((orOn && orKey != null) || zenOn) {
      try {
        final ocr = await ocrBytesToText(imgBytes);
        if (ocr.trim().isNotEmpty) {
          effectivePrompt =
              '$prompt\nTEKS GAMBAR (OCR lokal):\n$ocr';
          viaOcr = true;
        }
      } on AiFailure catch (e) {
        note(e);
      } catch (e) {
        note(AiFailure('network', '[OCR] $e'));
      }
    }
  }
  if (await aiProviderOn(aiProvOr)) {
    final k = await readOrKey();
    if (k != null) {
      try {
        final t = await orChatRaw(apiKey: k, prompt: effectivePrompt)
            .timeout(const Duration(seconds: 75));
        return (
          text: t,
          provider: 'OpenRouter: $aiOrModel${viaOcr ? ' (OCR)' : ''}'
        );
      } on AiFailure catch (e) {
        note(e);
      } catch (e) {
        note(AiFailure('network', '[OpenRouter] $e'));
      }
    }
  }
  if (await aiProviderOn(aiProvZen)) {
    try {
      final zk = await readZenKey();
      final r = await zenChatRaw(apiKey: zk, prompt: effectivePrompt)
          .timeout(const Duration(seconds: 75));
      if (r.text.trim().isNotEmpty) {
        return (
          text: r.text,
          provider: 'Zen: ${r.provider}${viaOcr ? ' (OCR)' : ''}'
        );
      }
    } on AiFailure catch (e) {
      note(e);
    } catch (e) {
      note(AiFailure('network', '[Zen] $e'));
    }
  }
  if (await aiProviderOn(aiProvFb)) {
    try {
      final img = imageBytes;
      if (hasImage && img != null) {
        final gen = await firebaseAiGenerate();
        if (gen != null) {
          final t = await firebaseVisionAsk(
            bytes: img,
            prompt: prompt,
            mimeType: mimeType,
          );
          if (t != null && t.trim().isNotEmpty) {
            return (text: t, provider: 'Firebase');
          }
        }
      } else {
        final gen = await firebaseAiGenerate();
        if (gen != null) {
          final t =
              await gen(prompt).timeout(const Duration(seconds: 60));
          if (t != null && t.trim().isNotEmpty) {
            return (text: t, provider: 'Firebase');
          }
        }
      }
    } on AiFailure catch (e) {
      note(e);
    } catch (e) {
      note(AiFailure('network', '$e'));
    }
  }
  if (hasImage && last == null) {
    throw const AiFailure(
        'server', '[Gambar] butuh kunci Gemini atau login Firebase');
  }
  throw last ?? const AiFailure('network', 'semua provider mati/nonaktif');
}

/// Rantai teks murni (tanpa gambar/vision): OpenRouter -> Zen ->
/// Firebase-teks, hormati toggle. Untuk Scan AI yang jatuh ke OCR.
/// Throw error terakhir. Tak kirim foto (prompt teks saja).
Future<({String text, String provider})> aiTextChain(
  String fullPrompt,
) async {
  AiFailure? last;
  void note(AiFailure e) {
    last = e;
    if (e.code == 'quota') unawaited(noteQuotaHit());
  }
  if (await aiProviderOn(aiProvOr)) {
    final k = await readOrKey();
    if (k != null) {
      try {
        final t = await orChatRaw(apiKey: k, prompt: fullPrompt)
            .timeout(const Duration(seconds: 75));
        return (text: t, provider: 'OpenRouter: $aiOrModel');
      } on AiFailure catch (e) {
        note(e);
      } catch (e) {
        note(AiFailure('network', '[OpenRouter] $e'));
      }
    }
  }
  if (await aiProviderOn(aiProvZen)) {
    try {
      final zk = await readZenKey();
      final r = await zenChatRaw(apiKey: zk, prompt: fullPrompt)
          .timeout(const Duration(seconds: 75));
      if (r.text.trim().isNotEmpty) {
        return (text: r.text, provider: 'Zen: ${r.provider}');
      }
    } on AiFailure catch (e) {
      note(e);
    } catch (e) {
      note(AiFailure('network', '[Zen] $e'));
    }
  }
  if (await aiProviderOn(aiProvFb)) {
    try {
      final gen = await firebaseAiGenerate();
      if (gen != null) {
        final t =
            await gen(fullPrompt).timeout(const Duration(seconds: 60));
        if (t != null && t.trim().isNotEmpty) {
          return (text: t, provider: 'Firebase');
        }
      }
    } on AiFailure catch (e) {
      note(e);
    } catch (e) {
      note(AiFailure('network', '$e'));
    }
  }
  throw last ?? const AiFailure('network', 'semua provider mati/nonaktif');
}
