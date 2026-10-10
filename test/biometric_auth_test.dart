import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/biometric_auth.dart';

void main() {
  test('tanpa platform (unit test): gagal tertutup, tak melempar', () async {
    // Di test env tak ada MethodChannel biometrik: wajib false + alasan
    // tercatat (regresi bug "tombol diam tanpa pesan").
    final ok = await BiometricAuth.unlock('test');
    expect(ok, isFalse);
    expect(BiometricAuth.lastError, isNotNull);
  });

  test('isSupported tanpa platform = false, tak melempar', () async {
    expect(await BiometricAuth.isSupported(), isFalse);
  });
}
