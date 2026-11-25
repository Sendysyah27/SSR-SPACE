import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';

/// Cadangan terenkripsi — format baru (2026-11-25): AES-256-GCM berpassword
/// dengan kunci diturunkan PBKDF2-HMAC-SHA256 (210k iterasi). Payload =
/// base64(salt(16) || nonce(12) || mac(16) || ciphertext) ber-marker
/// [encBackupMarker2]. GCM memberi confidentiality + integrity (tag
/// diverifikasi saat dekripsi), jadi file tak bisa diubah tanpa ketahuan.
///
/// Format lama ZipCrypto ([encBackupMarker]) TIDAK diautentikasi dan lemah;
/// masih bisa DIBACA demi kompatibilitas backup lama, tapi enkripsi baru
/// tak pernah memakainya lagi.
const encBackupMarker = 'SSR-ENC1:'; // legacy ZipCrypto (read-only)
const encBackupMarker2 = 'SSR-ENC2:'; // AES-256-GCM (write)

const _saltLen = 16;
const _nonceLen = 12;
const _macLen = 16;

/// OWASP 2023 merekomendasikan minimal 210.000 iterasi PBKDF2-HMAC-SHA256.
const _kdfIterations = 210000;

/// True bila [payload] tampak sebagai cadangan terenkripsi (format baru
/// atau lama). Dipakai UI untuk memutuskan perlu-tanya-password atau tidak.
bool isEncBackup(String payload) {
  final t = payload.trim();
  return t.startsWith(encBackupMarker) || t.startsWith(encBackupMarker2);
}

List<int> _randomBytes(int n) =>
    List<int>.generate(n, (_) => Random.secure().nextInt(256));

Future<SecretKey> _deriveKey(String password, List<int> salt) =>
    Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: _kdfIterations, bits: 256)
        .deriveKeyFromPassword(password: password, nonce: salt);

/// Enkripsi [plainJson] menjadi teks siap-share (AES-256-GCM).
/// Password minimal 8 karakter divalidasi di UI, bukan di sini.
Future<String> encryptBackup(String plainJson, String password) async {
  final gcm = AesGcm.with256bits();
  final nonce = gcm.newNonce();
  final salt = _randomBytes(_saltLen);
  final key = await _deriveKey(password, salt);
  final box =
      await gcm.encrypt(utf8.encode(plainJson), secretKey: key, nonce: nonce);
  final packed = <int>[
    ...salt,
    ...box.nonce,
    ...box.mac.bytes,
    ...box.cipherText,
  ];
  return encBackupMarker2 + base64Encode(packed);
}

/// Dekripsi payload hasil [encryptBackup] (atau format lama SSR-ENC1) menjadi
/// JSON asli. Throw [BackupDecryptException] bila format/password salah/rusak.
Future<String> decryptBackup(String payload, String password) async {
  final t = payload.trim();
  if (t.startsWith(encBackupMarker2)) {
    return _decryptAesGcm(t.substring(encBackupMarker2.length), password);
  }
  if (t.startsWith(encBackupMarker)) {
    return _decryptLegacyZip(t.substring(encBackupMarker.length), password);
  }
  throw const BackupDecryptException('bukan cadangan terenkripsi SSR SPACE');
}

Future<String> _decryptAesGcm(String b64, String password) async {
  late final List<int> packed;
  try {
    packed = base64Decode(b64);
  } catch (_) {
    throw const BackupDecryptException('payload rusak (base64)');
  }
  if (packed.length < _saltLen + _nonceLen + _macLen) {
    throw const BackupDecryptException('arsip rusak');
  }
  final salt = packed.sublist(0, _saltLen);
  final nonce = packed.sublist(_saltLen, _saltLen + _nonceLen);
  final mac =
      packed.sublist(_saltLen + _nonceLen, _saltLen + _nonceLen + _macLen);
  final ct = packed.sublist(_saltLen + _nonceLen + _macLen);
  try {
    final key = await _deriveKey(password, salt);
    final box = SecretBox(ct, nonce: nonce, mac: Mac(mac));
    final clear = await AesGcm.with256bits().decrypt(box, secretKey: key);
    return utf8.decode(clear);
  } on SecretBoxAuthenticationError {
    // Tag GCM gagal = password salah ATAU isi file diubah.
    throw const BackupDecryptException('password salah');
  } catch (_) {
    throw const BackupDecryptException('arsip rusak');
  }
}

/// Format lama ZipCrypto (SSR-ENC1) — hanya baca. Tidak diautentikasi.
String _decryptLegacyZip(String b64, String password) {
  late final List<int> zipBytes;
  try {
    zipBytes = base64Decode(b64);
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
