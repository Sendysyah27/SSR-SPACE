import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/receipt_currency.dart';

// Batch 284 tahap B: CurrencyResolver struk asing — deteksi mata uang,
// parse kurs open.er-api.com, konversi, format tampil. Semua murni.

void main() {
  group('detectReceiptCurrency', () {
    test('simbol khas', () {
      expect(detectReceiptCurrency('TOTAL ¥1,580'), 'JPY');
      expect(detectReceiptCurrency('合計 1580円'), 'JPY');
      expect(detectReceiptCurrency('합계 ₩12,000'), 'KRW');
      expect(detectReceiptCurrency('TOTAL ฿350'), 'THB');
      expect(detectReceiptCurrency('TOTAL €9,99'), 'EUR');
    });

    test('dolar: S\$ = SGD, \$ polos = USD', () {
      expect(detectReceiptCurrency('TOTAL S\$ 30.00'), 'SGD');
      expect(detectReceiptCurrency('TOTAL \$25.00'), 'USD');
      expect(detectReceiptCurrency('US\$ 25'), 'USD');
    });

    test('RM ringgit, bukan Rp', () {
      expect(detectReceiptCurrency('JUMLAH RM45.90'), 'MYR');
      expect(detectReceiptCurrency('TOTAL RM 120.00'), 'MYR');
    });

    test('kode eksplisit 3 huruf', () {
      expect(detectReceiptCurrency('Total: 1580 JPY'), 'JPY');
      expect(detectReceiptCurrency('TOTAL 12000 KRW'), 'KRW');
      expect(detectReceiptCurrency('AMOUNT 45.90 MYR'), 'MYR');
    });

    test('rupiah / teks biasa -> null', () {
      expect(detectReceiptCurrency('TOTAL Rp 50.000'), isNull);
      expect(detectReceiptCurrency('Indomaret belanja 50000'), isNull);
      expect(detectReceiptCurrency('SUPERMARKET'), isNull);
      expect(detectReceiptCurrency(''), isNull);
    });
  });

  group('parseErApiRate', () {
    test('fixture sukses', () {
      const body =
          '{"result":"success","base_code":"JPY","rates":{"JPY":1,"IDR":105.25}}';
      expect(parseErApiRate(body), 105.25);
    });

    test('IDR integer diterima', () {
      const body = '{"result":"success","rates":{"IDR":16000}}';
      expect(parseErApiRate(body), 16000.0);
    });

    test('tanpa IDR / bukan JSON -> null', () {
      expect(parseErApiRate('{"result":"success","rates":{"USD":1}}'), isNull);
      expect(parseErApiRate('bukan json'), isNull);
      expect(parseErApiRate('{"rates":null}'), isNull);
    });
  });

  test('convertToIdr', () {
    expect(convertToIdr(1580, 105), 165900);
    expect(convertToIdr(0, 105), 0);
  });

  group('formatForeignAmount', () {
    test('JPY tanpa desimal + grup ribuan', () {
      expect(formatForeignAmount(1580, 'JPY'), '¥ 1.580');
      expect(formatForeignAmount(12000, 'KRW'), '₩ 12.000');
    });

    test('USD/MYR dua desimal koma', () {
      expect(formatForeignAmount(12.5, 'USD'), '\$ 12,50');
      expect(formatForeignAmount(45.9, 'MYR'), 'RM 45,90');
      expect(formatForeignAmount(350, 'THB'), '฿ 350,00');
    });
  });
}
