import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'ai_soul.dart';
import 'firebase_ai_parser.dart';

// OpenCode CLI native (Android) sebagai provider AI pengganti Zen.
//
// Latar: endpoint Zen (/zen/v1) menolak request dari luar client OpenCode
// (403 FreeTierError, kebijakan resmi sejak Sep 2026). Binary `opencode`
// yang asli — NDK Android-native (Bionic, tanpa glibc) — tetap dapat
// free tier karena request-nya memang datang dari client OpenCode.
//
// Cara kerja:
//  1. ensureCliBinary(): unduh sekali binary 171MB ke app support dir,
//     verifikasi SHA256, chmod +x. Pemakaian berikutnya langsung pakai.
//  2. aiChatViaCli(): bangun prompt (history + dataContext + prompt,
//     pola sama kayak aiChat), tulis gambar ke temp file bila ada,
//     lalu Process.run: opencode run --format json -m <model> [-f img] prompt
//  3. Parse stdout sebagai JSONL, kumpulkan semua event text.
//  4. Bila model utama gagal (exit != 0 / FreeTierError), coba fallback
//     berikutnya sampai habis.
// Throw [AiFailure] jujur (kode: empty | timeout | network | denied | server).

/// URL binary opencode v1.18.9 (Android aarch64, NDK-native).
const cliDownloadUrl =
    'https://github.com/Sendysyah27/SSR-SPACE/releases/download/opencode-bin-v1.18.9/opencode';

/// SHA256 dari binary di atas (wajib cocok, kalau tidak file dihapus).
const cliSha256 =
    '622c01ffee1f9b38cb334282cd4795ad997d470357a263da9405727458bb72ce';

/// Model utama (format provider/model untuk flag -m).
const cliModelPrimary = 'opencode/muse-spark-1.3-contributor-free';

/// Fallback berurutan — hanya model yang confirmed ada di `opencode models`.
const cliModelFallbacks = [
  'opencode/longcat-2.5-preview-free',
  'opencode/space-bunny-free',
  'opencode/nemotron-3.5-lightning-free',
];

const cliProviderName = 'opencode-cli';
const cliTimeout = Duration(seconds: 120);

String _snip(String s, [int max = 300]) =>
    s.length <= max ? s : '${s.substring(0, max)}...';

/// Pastikan binary tersedia & executable. Return path absolut binary.
/// Download + verifikasi SHA256 hanya saat file belum ada.
Future<String> ensureCliBinary() async {
  final support = await getApplicationSupportDirectory();
  final dir = Directory('${support.path}/opencode-cli');
  final bin = File('${dir.path}/opencode');
  if (await bin.exists()) {
    try {
      await Process.run('chmod', ['+x', bin.path]);
    } catch (_) {}
    return bin.path;
  }
  await dir.create(recursive: true);
  final tmp = File('${dir.path}/opencode.download');
  final client = http.Client();
  try {
    final req = http.Request('GET', Uri.parse(cliDownloadUrl));
    final streamed =
        await client.send(req).timeout(const Duration(minutes: 10));
    if (streamed.statusCode != 200) {
      throw AiFailure(
          'network', '[CLI] download HTTP ${streamed.statusCode}');
    }
    final sink = tmp.openWrite();
    try {
      await streamed.stream.pipe(sink);
    } finally {
      await sink.close();
    }
  } finally {
    client.close();
  }
  // Verifikasi SHA256 (streaming, tanpa load 171MB ke RAM).
  final digest = await sha256.bind(tmp.openRead()).first;
  if (digest.toString().toLowerCase() != cliSha256.toLowerCase()) {
    try {
      await tmp.delete();
    } catch (_) {}
    throw const AiFailure(
        'network', '[CLI] SHA256 binary tidak cocok, file dihapus');
  }
  await tmp.rename(bin.path);
  final chmod = await Process.run('chmod', ['+x', bin.path]);
  if (chmod.exitCode != 0) {
    throw AiFailure(
        'server', '[CLI] chmod gagal: ${_snip('${chmod.stderr}')}');
  }
  return bin.path;
}

/// Kumpulkan teks dari stdout JSONL `opencode run --format json`.
/// Menangani dua bentuk event: {"type":"text","delta":"..."} (streaming)
/// dan {"type":"text","part":{"text":"..."}} (full).
String parseCliJsonl(String out) {
  final buf = StringBuffer();
  for (final line in out.split('\n')) {
    final t = line.trim();
    if (t.isEmpty || !t.startsWith('{')) continue;
    Map<String, dynamic>? obj;
    try {
      final d = jsonDecode(t);
      if (d is Map<String, dynamic>) obj = d;
    } catch (_) {
      continue;
    }
    if (obj == null || obj['type'] != 'text') continue;
    final delta = obj['delta'];
    if (delta is String && delta.isNotEmpty) {
      buf.write(delta);
      continue;
    }
    final part = obj['part'];
    if (part is Map) {
      final txt = part['text'];
      if (txt is String) buf.write(txt);
    }
  }
  return buf.toString();
}

/// Satu pemanggilan CLI untuk satu model. Return teks jawaban.
/// Throw [AiFailure] bila gagal (pemanggil memutuskan fallback).
Future<String> runCliOnce({
  required String bin,
  required String model,
  required String prompt,
  String? imagePath,
  required String home,
  required String tmpdir,
}) async {
  final args = <String>[
    'run',
    '--format',
    'json',
    '-m',
    model,
    if (imagePath != null) ...['-f', imagePath],
    prompt,
  ];
  ProcessResult res;
  try {
    res = await Process.run(
      bin,
      args,
      environment: {
        'HOME': home,
        'TMPDIR': tmpdir,
        'PATH': '/system/bin',
      },
    ).timeout(cliTimeout);
  } on TimeoutException catch (e) {
    throw AiFailure('timeout', '[CLI] $e');
  } catch (e) {
    throw AiFailure('server', '[CLI] gagal menjalankan binary: $e');
  }
  final out = '${res.stdout ?? ''}';
  final err = '${res.stderr ?? ''}';
  if (err.contains('FreeTierError') ||
      err.contains('can only be used from within OpenCode')) {
    throw AiFailure('denied', '[CLI:$model] ${_snip(err)}');
  }
  if (res.exitCode != 0) {
    throw AiFailure(
        'server', '[CLI:$model] exit ${res.exitCode} ${_snip(err)}');
  }
  final text = parseCliJsonl(out);
  if (text.trim().isEmpty) {
    throw AiFailure('empty', '[CLI:$model] tanpa teks ${_snip(err)}');
  }
  return text;
}

/// Chat bebas via OpenCode CLI native. Signature sama kayak [aiChat]
/// di ai_zen_client.dart biar gampang di-swap.
/// [imageBytes] ditulis ke temp file lalu di-attach via flag -f.
/// [history] & [dataContext] digabung jadi satu prompt.
//  Return (teks, provider). Throw [AiFailure] terakhir yang jujur.
Future<({String text, String provider})> aiChatViaCli(
  String prompt, {
  List<int>? imageBytes,
  String? mimeType,
  List<({bool mine, String text})>? history,
  String? dataContext,
}) async {
  if (prompt.trim().isEmpty) {
    throw const AiFailure('empty', 'prompt kosong');
  }
  final convo = (history == null || history.isEmpty)
      ? ''
      : '${chatHistoryBlock(history)}\n';
  final data = (dataContext ?? '').trim().isNotEmpty
      ? '${dataContext!.trim()}\n'
      : '';
  final full = '$convo$data$prompt';

  final bin = await ensureCliBinary();
  final support = await getApplicationSupportDirectory();
  final tmp = await getTemporaryDirectory();

  String? imagePath;
  File? imgFile;
  try {
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final ext =
          (mimeType ?? '').toLowerCase().contains('png') ? 'png' : 'jpg';
      imgFile = File('${tmp.path}/opencode-cli-img.$ext');
      await imgFile.writeAsBytes(imageBytes);
      imagePath = imgFile.path;
    }
    final models = [cliModelPrimary, ...cliModelFallbacks];
    AiFailure? lastErr;
    for (final m in models) {
      try {
        final text = await runCliOnce(
          bin: bin,
          model: m,
          prompt: full,
          imagePath: imagePath,
          home: support.path,
          tmpdir: tmp.path,
        );
        return (text: text, provider: cliProviderName);
      } on AiFailure catch (e) {
        lastErr = e;
        continue; // coba model berikutnya
      }
    }
    throw lastErr ?? const AiFailure('server', '[CLI] semua model gagal');
  } finally {
    // Bersihkan file gambar temp (best effort).
    try {
      await imgFile?.delete();
    } catch (_) {}
  }
}
