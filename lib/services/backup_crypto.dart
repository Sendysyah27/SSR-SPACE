import 'dart:convert';

import 'package:archive/archive.dart';

/// Cadangan terenkripsi: JSON dibungkus zip AES-256 berpassword lalu
/// di-base64 dengan marker, agar bisa ditempel sebagai teks di dialog
/// restore yang sudah ada (paste-based) tanpa file picker baru.
const encBackupMarker = 'SSR-ENC1:';

/// Enkripsi [plainJson] menjadi teks siap-share.
/// Password minimal 8 karakter divalidasi di UI, bukan di sini.
String encryptBackup(String plainJson, String password) {
  final archive = Archive()
    ..add(ArchiveFile.string('backup.json', plainJson));
  final zipBytes = ZipEncoder(password: password).encodeBytes(archive);
  return encBackupMarker + base64Encode(zipBytes);
}

/// Dekripsi payload hasil [encryptBackup] menjadi JSON asli.
/// Throw [BackupDecryptException] bila format salah / password salah.
String decryptBackup(String payload, String password) {
  final t = payload.trim();
  if (!t.startsWith(encBackupMarker)) {
    throw const BackupDecryptException('bukan cadangan terenkripsi SSR SPACE');
  }
  late final List<int> zipBytes;
  try {
    zipBytes = base64Decode(t.substring(encBackupMarker.length));
  } catch (_) {
    throw const BackupDecryptException('payload rusak (base64)');
  }
  // Catatan: ArchiveException password-salah baru muncul saat content
  // dibaca (lazy decode), jadi seluruh baca dibungkus try yang sama.
  try {
    final archive = ZipDecoder().decodeBytes(zipBytes, password: password);
    if (archive.files.isEmpty) {
      throw const BackupDecryptException('arsip kosong');
    }
    final content = archive.files.first.content as List<int>;
    return utf8.decode(content);
  } on BackupDecryptException {
    rethrow;
  } on ArchiveException catch (e) {
    // archive 4.x: password salah = ArchiveException('Wrong password ...').
    if (e.message.toLowerCase().contains('password')) {
      throw const BackupDecryptException('password salah');
    }
    throw const BackupDecryptException('arsip rusak');
  } catch (_) {
    throw const BackupDecryptException('arsip rusak');
  }
}

class BackupDecryptException implements Exception {
  final String message;
  const BackupDecryptException(this.message);
  @override
  String toString() => 'BackupDecryptException: $message';
}
