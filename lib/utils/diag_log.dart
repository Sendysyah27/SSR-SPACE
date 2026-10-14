// Diagnostic file logger — tulis ke /sdcard/ssr_debug.log
// Hanya untuk build diagnostik FC silent. Fail-silent total.
import 'dart:io';

class DiagLog {
  static const _path = '/sdcard/ssr_debug.log';
  static bool _ok = true;

  static void write(String label) {
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
