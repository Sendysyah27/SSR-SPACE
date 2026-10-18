import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/backup_crypto.dart';

void main() {
  const sample = '{"app":"ssr-space","wallets":[],"txs":[]}';
  const pass = 'rahasia123';

  test('roundtrip enkripsi-dekripsi', () {
    final enc = encryptBackup(sample, pass);
    expect(enc.startsWith(encBackupMarker), true);
    expect(decryptBackup(enc, pass), sample);
  });

  test('password salah -> BackupDecryptException', () {
    final enc = encryptBackup(sample, pass);
    expect(
      () => decryptBackup(enc, 'salah1234'),
      throwsA(isA<BackupDecryptException>()),
    );
  });

  test('bukan payload terenkripsi -> throw', () {
    expect(
      () => decryptBackup('{"a":1}', pass),
      throwsA(isA<BackupDecryptException>()),
    );
  });

  test('base64 rusak -> throw', () {
    expect(
      () => decryptBackup('$encBackupMarker!!!', pass),
      throwsA(isA<BackupDecryptException>()),
    );
  });
}
