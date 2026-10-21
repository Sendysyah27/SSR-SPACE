import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/receipt_parse.dart';

// Batch 286 tahap A: kasus nyata laporan user 21 Okt 2026 — struk
// SANCHA (Tunjungan Plaza 3) yang dulu terbaca ngaco oleh parser OCR
// lokal lama (judul "Sales No", nominal Rp 0, jam hilang). Teks di
// bawah = rekonstruksi representatif hasil ML Kit dari foto struk.
const _sancha = '''
SANCHA
Tunjungan Plaza 3
Sales No : SSTPZ178887009566
Date : 08-09-2026 19:21
Purpose : TAKEAWAY
Cashier : Fina
Da Hong Pao Milk Tea (M)
1x @32.000 32.000
No Ice
1x @0 0
Lite Sugar
1x @0 0
SANCHA DAY 50%
0
1 item
Menu Discount : -16.000
Grand Total : 16.000
QRIS BCA : 16.000
- Thank You -
Your queue number
206
''';

// Varian dua kolom: label dan angka di baris terpisah (ML Kit sering
// memisahkan kolom kanan struk jadi baris sendiri).
const _sanchaSplit = '''
SANCHA
Tunjungan Plaza 3
Sales No : SSTPZ178887009566
Date : 08-09-2026 19:21
Purpose : TAKEAWAY
Cashier : Fina
Da Hong Pao Milk Tea (M)
1x @32.000
32.000
1 item
Menu Discount :
-16.000
Grand Total :
16.000
QRIS BCA :
16.000
''';

// Varian tanpa Grand Total & tanpa diskon: hanya "TOTAL".
const _totalOnly = '''
TOKO KOPI ABC
Jl. Merdeka No. 10
Kopi Tubruk
1x @15.000 15.000
Roti Bakar
1x @30.000 30.000
TOTAL : 45.000
Tunai : 50.000
Kembali : 5.000
''';

void main() {
  test('SANCHA: merchant = brand di kepala struk, bukan label kolom', () {
    final r = parseReceipt(_sancha);
    expect(r.merchant, 'SANCHA');
  });

  test('SANCHA: total = Grand Total sesudah diskon, bukan Rp 0', () {
    final r = parseReceipt(_sancha);
    expect(r.amount, 16000);
    expect(r.confident, isTrue);
    expect(r.inconsistent, isFalse);
  });

  test('SANCHA: diskon Inggris "Menu Discount" tercatat sebagai voucher',
      () {
    final r = parseReceipt(_sancha);
    expect(r.voucher, 16000);
    expect(r.items.any((i) => i.toLowerCase().contains('discount')),
        isFalse);
  });

  test('SANCHA: tanggal menangkap jam struk (19:21)', () {
    final r = parseReceipt(_sancha);
    expect(r.date, DateTime(2026, 9, 8));
    expect(r.time, '19:21');
  });

  test('SANCHA: satu item betulan; modifier Rp 0 bukan item', () {
    final r = parseReceipt(_sancha);
    expect(r.lineItems.length, 1);
    expect(r.lineItems.first.name, 'Da Hong Pao Milk Tea (M)');
    expect(r.lineItems.first.qty, 1);
    expect(r.lineItems.first.price, 32000);
  });

  test('SANCHA dua kolom: total tetap ketemu dari label telanjang', () {
    final r = parseReceipt(_sanchaSplit);
    expect(r.merchant, 'SANCHA');
    expect(r.amount, 16000);
    expect(r.lineItems.length, 1);
    expect(r.time, '19:21');
  });

  test('struk TOTAL saja tanpa diskon tetap utuh', () {
    final r = parseReceipt(_totalOnly);
    expect(r.merchant, 'TOKO KOPI ABC');
    expect(r.amount, 45000);
    expect(r.voucher, isNull);
    expect(r.lineItems.length, 2);
    expect(r.date, isNull);
  });
}
