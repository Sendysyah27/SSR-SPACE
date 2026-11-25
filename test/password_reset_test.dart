import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/password_reset_logic.dart';

void main() {
  test('cocok + cukup panjang = sah', () {
    expect(newPasswordError('rahasia1', 'rahasia1'), isNull);
  });

  test('beda = mismatch (menang atas cek panjang)', () {
    expect(newPasswordError('abc', 'abd'), 'mismatch');
  });

  test('pendek = short', () {
    expect(newPasswordError('abcde', 'abcde'), 'short');
  });

  test('kosong = short (bukan mismatch)', () {
    expect(newPasswordError('', ''), 'short');
  });

  test('tepat 6 char = short (kebijakan minimal 8)', () {
    expect(newPasswordError('abcdef', 'abcdef'), 'short');
  });

  test('tepat 8 char = sah', () {
    expect(newPasswordError('abcdefgh', 'abcdefgh'), isNull);
  });
}
