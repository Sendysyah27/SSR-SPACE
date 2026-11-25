import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/password_reset_logic.dart';

void main() {
  test('mismatch didahulukan sebelum panjang', () {
    expect(newPasswordError('abcdefgh', 'abcdefgi'), 'mismatch');
    // pendek DAN tak sama -> tetap mismatch (urutan mismatch dulu)
    expect(newPasswordError('abc', 'abd'), 'mismatch');
  });

  test('short bila < 8 karakter (default minLen)', () {
    expect(newPasswordError('abcdefg', 'abcdefg'), 'short');
    expect(newPasswordError('', ''), 'short');
  });

  test('weak untuk sandi umum (tanpa peduli besar-kecil huruf)', () {
    expect(newPasswordError('password', 'password'), 'weak');
    expect(newPasswordError('12345678', '12345678'), 'weak');
    expect(newPasswordError('123456789', '123456789'), 'weak');
    expect(newPasswordError('password1', 'password1'), 'weak');
    expect(newPasswordError('qwerty123', 'qwerty123'), 'weak');
    expect(newPasswordError('11111111', '11111111'), 'weak');
    expect(newPasswordError('admin123', 'admin123'), 'weak');
    expect(newPasswordError('PassWord', 'PassWord'), 'weak');
  });

  test('ok bila cukup panjang dan tak masuk blok', () {
    expect(newPasswordError('sandiku123', 'sandiku123'), isNull);
    expect(newPasswordError('abcdefgh', 'abcdefgh'), isNull);
  });

  test('minLen bisa di-override', () {
    expect(newPasswordError('abcdef', 'abcdef', minLen: 6), isNull);
    expect(newPasswordError('abcde', 'abcde', minLen: 6), 'short');
  });
}
