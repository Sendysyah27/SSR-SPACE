import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// File-logger diagnostik crash lock/unlock. SEMENTARA, hapus setelah
/// vonis (hanya dipakai build -debug).
///
/// Tulis ke /sdcard/Download/SSR-SPACE/pin-debug.log + timestamp ISO.
/// Semua fungsi fail-open: logger tak boleh crash app. Izin diminta
/// malas (sekali per sesi) hanya bila tulis langsung gagal.
const _kLogPath = '/sdcard/Download/SSR-SPACE/pin-debug.log';

bool _permTried = false;
bool _permOk = false;

Future<void> _ensure() async {
  if (_permOk) return;
  try {
    await File(_kLogPath).parent.create(recursive: true);
    await File(_kLogPath).writeAsString('', mode: FileMode.append);
    _permOk = true;
    return;
  } catch (_) {}
  if (_permTried) return;
  _permTried = true;
  try {
    if (await Permission.manageExternalStorage.isGranted) {
      _permOk = true;
      return;
    }
    _permOk =
        (await Permission.manageExternalStorage.request()).isGranted;
  } catch (_) {}
}

String _ts() {
  final n = DateTime.now();
  String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
  return '${p(n.year, 4)}-${p(n.month)}-${p(n.day)} '
      '${p(n.hour)}:${p(n.minute)}:${p(n.second)}.${p(n.millisecond, 3)}';
}

Future<void> _write(String line) async {
  try {
    await _ensure();
    if (!_permOk) return;
    await File(_kLogPath).writeAsString(
      '[${_ts()}] $line\n',
      mode: FileMode.append,
    );
  } catch (_) {}
}

/// Satu baris langkah. Dipanggil di tiap tahap lock/unlock flow.
Future<void> pinLog(String step) => _write('STEP $step');

/// Error + stack satu tahap. Dipanggil di tiap catch lock/unlock flow.
Future<void> pinLogError(String step, Object e, StackTrace st) =>
    _write('ERROR $step :: $e\n$st');

/// Mulai log sesi baru (dipanggil sekali di main).
Future<void> clearPinLog() async {
  try {
    await _ensure();
    if (!_permOk) return;
    await File(_kLogPath).writeAsString(
      '[${_ts()}] === BOOT pin-debug ===\n',
    );
  } catch (_) {}
}
