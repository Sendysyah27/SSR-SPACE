import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Ditolak user (atau dibatasi OEM): pemanggil wajib fallback jujur
/// (share sheet + pesan), bukan error generik.
class ExportNoPermission implements Exception {
  const ExportNoPermission();
}

/// Simpan file ekspor ke `Documents/ssr-space/` milik user.
///
/// Kembalikan path absolut file yang tertulis. Non-Android (iOS/desktop)
/// langsung ke direktori dokumen app tanpa minta izin (aturan platform).
/// Android: kelola izin dulu; ditolak = [ExportNoPermission]. Tak melempar
/// selain itu kecuali I/O benar-benar gagal (disk penuh, dsb).
Future<String> saveToDocuments({
  required String fileName,
  required Future<void> Function(String path) write,
}) async {
  if (!Platform.isAndroid) {
    final dir = await getApplicationDocumentsDirectory();
    final target = Directory('${dir.path}/ssr-space');
    await target.create(recursive: true);
    final path = '${target.path}/$fileName';
    await write(path);
    return path;
  }
  if (!await _ensureWriteAccess()) {
    throw const ExportNoPermission();
  }
  const root = '/storage/emulated/0/Documents/ssr-space';
  final target = Directory(root);
  await target.create(recursive: true);
  final path = '$root/$fileName';
  await write(path);
  return path;
}

/// Izin tulis kolektif: MANAGE (API 30+) dulu, WRITE klasik sesudahnya
/// (API <30; di API baru hasilnya denied dan diabaikan). Keduanya gagal
/// berarti user/OEM menolak: pemanggil fallback, bukan crash.
Future<bool> _ensureWriteAccess() async {
  if (await Permission.manageExternalStorage.isGranted) return true;
  try {
    if ((await Permission.manageExternalStorage.request()).isGranted) {
      return true;
    }
  } catch (_) {}
  if (await Permission.storage.isGranted) return true;
  try {
    return (await Permission.storage.request()).isGranted;
  } catch (_) {
    return false;
  }
}
