import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/utils/currency.dart';

void main() {
  group('currencyByCode', () {
    test('returns IDR for unknown code', () {
      expect(currencyByCode('XXX').code, 'IDR');
    });

    test('is case insensitive', () {
      expect(currencyByCode('usd').code, 'USD');
      expect(currencyByCode('Usd').code, 'USD');
    });

    test('finds all supported currencies', () {
      for (final c in supportedCurrencies) {
        expect(currencyByCode(c.code).code, c.code);
      }
    });
  });

  group('formatMoney', () {
    test('formats IDR without decimals', () {
      final s = formatMoney(1250000, 'IDR');
      expect(s.contains('1.250.000'), true);
    });

    test('defaults to IDR', () {
      final s = formatMoney(1000);
      expect(s.contains('Rp'), true);
    });

    test('formats USD with 2 decimals', () {
      final s = formatMoney(1234.5, 'USD');
      expect(s.contains('1,234.50'), true);
    });

    test('fallback to IDR for unknown code', () {
      final s = formatMoney(1000, 'XXX');
      expect(s.contains('Rp'), true);
    });
  });

  group('supportedCurrencies', () {
    test('has 8 currencies with IDR first', () {
      expect(supportedCurrencies.length, 8);
      expect(supportedCurrencies.first.code, 'IDR');
    });
  });
}
