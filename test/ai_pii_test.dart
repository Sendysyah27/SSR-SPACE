import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/ai_pii.dart';

void main() {
  group('maskPii — yang WAJIB termasking', () {
    test('nomor kartu berkelompok spasi', () {
      final out = maskPii('kartu saya 4111 1111 1111 1111 ya');
      expect(out, contains('****1111'));
      expect(out, isNot(contains('4111 1111')));
    });
    test('nomor kartu polos 16 digit', () {
      final out = maskPii('cc 4111111111111111');
      expect(out, contains('****1111'));
      expect(out, isNot(contains('4111111111111111')));
    });
    test('rangkaian 13 digit polos (pola rekening panjang)', () {
      final out = maskPii('tagihan 1234567890123');
      expect(out, contains('****0123'));
      expect(out, isNot(contains('1234567890123')));
    });
    test('telepon 08...', () {
      final out = maskPii('hubungi 081234567890 ya');
      expect(out, contains('0812****890'));
      expect(out, isNot(contains('081234567890')));
    });
    test('telepon +62...', () {
      final out = maskPii('wa +6281234567890');
      expect(out, isNot(contains('6281234567890')));
      expect(out, contains('****'));
    });
    test('rekening 10 digit dengan konteks kata', () {
      final out = maskPii('transfer ke rek 1234567890 svp');
      expect(out, contains('****7890'));
      expect(out, isNot(contains('1234567890')));
    });
  });

  group('maskPii — nominal TIDAK boleh termasking (false positive)', () {
    test('kopi 20rb utuh', () {
      expect(maskPii('kopi 20rb'), 'kopi 20rb');
    });
    test('transfer 500000 utuh', () {
      expect(maskPii('transfer 500000 ke dana'), 'transfer 500000 ke dana');
    });
    test('format titik ribuan utuh', () {
      expect(maskPii('bayar 1.500.000'), 'bayar 1.500.000');
    });
    test('nominal 11 digit (miliaran) tanpa konteks utuh', () {
      expect(maskPii('gaji 15000000000 masuk'), 'gaji 15000000000 masuk');
    });
    test('teks tanpa angka utuh', () {
      expect(maskPii('catat makan siang tadi'), 'catat makan siang tadi');
    });
  });
}
