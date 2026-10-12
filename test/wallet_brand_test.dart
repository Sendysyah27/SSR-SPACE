import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/wallet_brand.dart';

void main() {
  test('DANA case-insensitive', () {
    final b = brandForWallet('DANA Bisnis');
    expect(b, isNotNull);
    expect(b!.short, 'DN');
  });

  test('BCA + warna ARGB valid', () {
    final b = brandForWallet('BCA Payroll');
    expect(b!.short, 'BCA');
    expect(b.argb & 0xFF000000, 0xFF000000);
  });

  test('Kas tanpa brand = null', () {
    expect(brandForWallet('Kas Tunai'), isNull);
    expect(brandForWallet(null), isNull);
    expect(brandForWallet('  '), isNull);
  });

  test('batas kata: Jagoan bukan Jago', () {
    expect(brandForWallet('Jagoan Kecil'), isNull);
    expect(brandForWallet('Bank Jago'), isNotNull);
  });

  test('alias umum cocok', () {
    expect(brandForWallet('GoPay')!.short, 'GP');
    expect(brandForWallet('ShopeePay')!.short, 'SP');
    expect(brandForWallet('Livin Mandiri')!.short, 'MDR');
  });
}
