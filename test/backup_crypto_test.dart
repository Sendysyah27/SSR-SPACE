import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/backup_crypto.dart';

void main() {
  const sample = '{"app":"ssr-space","wallets":[],"txs":[]}';
  const pass = 'rahasia123';

  test('roundtrip enkripsi-dekripsi (AES-256-GCM)', () async {
    final enc = await encryptBackup(sample, pass);
    expect(enc.startsWith(encBackupMarker2), true);
    expect(isEncBackup(enc), true);
    expect(await decryptBackup(enc, pass), sample);
  });

  test('nonce acak -> dua enkripsi identik menghasilkan cipher beda', () async {
    final a = await encryptBackup(sample, pass);
    final b = await encryptBackup(sample, pass);
    expect(a == b, false);
  });

  test('password salah -> BackupDecryptException', () async {
    final enc = await encryptBackup(sample, pass);
    expect(
      () => decryptBackup(enc, 'salah1234'),
      throwsA(isA<BackupDecryptException>()),
    );
  });

  test('bukan payload terenkripsi -> throw', () async {
    expect(
      () => decryptBackup('{"a":1}', pass),
      throwsA(isA<BackupDecryptException>()),
    );
  });

  test('base64 rusak -> throw', () async {
    expect(
      () => decryptBackup('${encBackupMarker2}!!!', pass),
      throwsA(isA<BackupDecryptException>()),
    );
  });

  test('payload terpotong -> throw (bukan crash)', () async {
    final enc = await encryptBackup(sample, pass);
    final trunc = enc.substring(0, enc.length - 8);
    expect(
      () => decryptBackup(trunc, pass),
      throwsA(isA<BackupDecryptException>()),
    );
  });
}
