// Diagnostic file logger — tulis ke /sdcard/ssr_debug.log
// Hanya untuk build diagnostik FC silent. Fail-silent total.
// MATI total di build rilis (kReleaseMode): isinya bisa memuat URL/host/ID
// dan /sdcard adalah storage bersama — jangan bocorkan info di rilis (P3-1).
import 'dart:io';

import 'package:flutter/foundation.dart';

class DiagLog {
  static const _path = '/sdcard/ssr_debug.log';
  static bool _ok = true;

  static void write(String label) {
    if (kReleaseMode) return; // fail-silent: tak menulis di rilis
    if (!_ok) return;
    try {
      final f = File(_path);
      final ts = DateTime.now().toIso8601String();
      f.writeAsStringSync('[$ts] $label\n', mode: FileMode.append);
    } catch (_) {
      _ok = false; // sdcard tak bisa ditulis, berhenti coba
    }
  }

  static void error(String label, Object e, [StackTrace? s]) {
    write('ERROR $label: $e');
    if (s != null) write(s.toString().split('\n').take(8).join('\n'));
  }
}
