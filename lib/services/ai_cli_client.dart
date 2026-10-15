import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

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
// v2.63.0: binary di-bundle sebagai native library di APK
// (android/app/src/main/jniLibs/arm64-v8a/libopencode.so).
// Alasan: Android 10+ memblokir eksekusi binary dari app-private dir
// (SELinux). Native lib dir (/data/app/.../lib/arm64/) BISA dieksekusi.
// Path ditemukan via /proc/self/maps (cari libflutter.so yang selalu
// ter-load, ambil direktorinya).
//
// Cara kerja:
//  1. ensureCliBinary(): parse /proc/self/maps -> nativeLibDir,
//     path = <nativeLibDir>/libopencode.so, chmod +x (best effort).
//  2. aiChatViaCli(): bangun prompt, Process.run binary.
//  3. Parse stdout JSONL, kumpulkan event text.
// Throw [AiFailure] jujur (kode: empty | timeout | denied | server).

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

/// Cari native library directory via MethodChannel (widget channel).
/// Channel ssr_space/widget sudah ada; method getNativeLibDir ditambahkan di CI.
Future<String> _findNativeLibDir() async {
  // Strategi 0: MethodChannel (paling reliable)
  try {
    const ch = MethodChannel('ssr_space/widget');
    final dir = await ch.invokeMethod<String>('getNativeLibDir');
    if (dir != null && dir.isNotEmpty) {
      final test = File('$dir/libopencode.so');
      if (await test.exists()) return dir;
    }
  } catch (_) {}
  // Fallback ke strategi lama jika channel gagal
  return _findNativeLibDirFallback();}

/// Fallback lama (jika MethodChannel tidak tersedia).
Future<String> _findNativeLibDirFallback() async {
  // Strategi 1: /proc/self/maps (cari libflutter.so)
  try {
    final maps = await File('/proc/self/maps').readAsString();
    for (final line in maps.split('\n')) {
      if (line.contains('libflutter.so') && line.contains('/')) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          final path = parts.last;
          if (path.startsWith('/')) {
            final dir = path.substring(0, path.lastIndexOf('/'));
            final test = File('$dir/libopencode.so');
            if (await test.exists()) return dir;
          }
        }
      }
    }
  } catch (_) {}

  // Strategi 2: scan /data/app untuk direktori package ini
  try {
    final appDir = Directory('/data/app');
    if (await appDir.exists()) {
      await for (final ent in appDir.list()) {
        final name = ent.path.split('/').last;
        if (name.contains('ssr_space') || name.contains('ssr.space')) {
          // Coba lib/arm64 dan lib/arm64-v8a
          for (final abi in ['arm64', 'arm64-v8a']) {
            final dir = '${ent.path}/lib/$abi';
            final test = File('$dir/libopencode.so');
            if (await test.exists()) return dir;
          }
          // Coba juga tanpa subdir lib (beberapa device)
          final test2 = File('${ent.path}/libopencode.so');
          if (await test2.exists()) return ent.path;
        }
      }
    }
  } catch (_) {}

  // Strategi 3: coba path umum langsung
  try {
    for (final abi in ['arm64-v8a', 'arm64']) {
      // Path tanpa /data/app prefix (kadang symlink)
      final candidates = [
        '/data/app/com.ssr.space.ssr_space/lib/$abi',
        '/data/app/com.ssr.space.ssr_space-1/lib/$abi',
        '/data/app/com.ssr.space.ssr_space-2/lib/$abi',
      ];
      for (final dir in candidates) {
        final test = File('$dir/libopencode.so');
        if (await test.exists()) return dir;
      }
    }
  } catch (_) {}

  throw const AiFailure(
      'server', '[CLI] native lib dir tidak ketemu (3 strategi gagal)');
}

/// Path binary opencode yang di-bundle di APK (native lib dir).
Future<String> ensureCliBinary() async {
  final nativeLibDir = await _findNativeLibDir();
  final bin = File('$nativeLibDir/libopencode.so');
  if (!await bin.exists()) {
    throw AiFailure(
        'server', '[CLI] binary tidak ketemu di $nativeLibDir');
  }
  try {
    await Process.run('chmod', ['+x', bin.path]);
  } catch (_) {}
  return bin.path;
}

/// Kumpulkan teks dari stdout JSONL `opencode run --format json`.
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

/// Chat bebas via OpenCode CLI native. Signature sama kayak [aiChat].
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
        continue;
      }
    }
    throw lastErr ?? const AiFailure('server', '[CLI] semua model gagal');
  } finally {
    try {
      await imgFile?.delete();
    } catch (_) {}
  }
}
