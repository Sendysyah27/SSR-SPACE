import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/ai_draft.dart';

void main() {
  test('JSON penuh valid', () {
    final d = parseAiDraft('''
{"merchant":"KOPI KENANGAN","date":"2026-10-12",
"items":[{"name":"Kopi Mantan","qty":1,"price":25000},
{"name":"Matcha Latte","qty":2,"price":50000}],
"subtotal":125000,"tax":0,"total":125000,"payment_method":"QRIS"}''');
    expect(d, isNotNull);
    expect(d!.merchant, 'KOPI KENANGAN');
    expect(d.items.length, 2);
    expect(d.items[1].qty, 2);
    expect(d.total, 125000);
    expect(d.payment, 'QRIS');
  });

  test('pagar fence diabaikan', () {
    final d = parseAiDraft(
      '```json\n{"merchant":"TOKO","total":5000}\n```',
    );
    expect(d!.merchant, 'TOKO');
    expect(d.total, 50000 - 45000);
  });

  test('parsial tetap lanjut (item saja)', () {
    final d = parseAiDraft('{"items":[{"name":"Kopi"}]}');
    expect(d, isNotNull);
    expect(d!.items.single.name, 'Kopi');
    expect(d.total, isNull);
  });

  test('sampah dan kosong = null', () {
    expect(parseAiDraft('maaf tidak bisa'), isNull);
    expect(parseAiDraft(''), isNull);
    expect(parseAiDraft('{}'), isNull);
    expect(parseAiDraft('[1,2]'), isNull);
  });

  test('item tanpa nama dibuang, harga negatif dibuang', () {
    final d = parseAiDraft(
      '{"items":[{"name":"","price":100},{"name":"A","price":-5},{"name":"B","price":1000}]}',
    );
    expect(d!.items.map((e) => e.name), ['B']);
  });

  test('prompt bawa skema + teks + aturan varian', () {
    final p = aiReceiptPrompt('KOPI\n25000');
    expect(p.contains('KOPI'), isTrue);
    expect(p.contains('merchant'), isTrue);
    expect(p.contains('items'), isTrue);
    expect(p.contains('varian'), isTrue);
    expect(p.contains('SELURUH'), isTrue);
    expect(p.contains('LENGKAP'), isTrue);
    expect(p.contains('paling kanan'), isTrue);
  });

  test('ke ReceiptData jujur', () {
    final d = parseAiDraft('{"merchant":"T","total":10000}')!;
    final r = d.toReceiptData();
    expect(r.amount, 10000);
    expect(r.merchant, 'T');
    expect(r.confident, isTrue);
  });
}
