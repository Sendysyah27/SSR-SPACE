import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/ai_draft.dart';
import 'package:ssr_space/services/receipt_parse.dart';

// Batch 286 tahap A: jembatan ReceiptData (parser lokal) <-> AiDraft
// (review terstruktur) — tanggal+jam, diskon, pajak, jenis bayar wajib
// utuh dua arah.
void main() {
  final data = ReceiptData(
    amount: 16000,
    date: DateTime(2026, 9, 8),
    time: '19:21',
    merchant: 'SANCHA',
    lineItems: const [
      ReceiptItem(name: 'Da Hong Pao Milk Tea (M)', qty: 1, price: 32000),
    ],
    voucher: 16000,
    payType: 'QRIS',
    confident: true,
  );

  test('fromReceiptData memetakan semua field kunci', () {
    final d = AiDraft.fromReceiptData(data);
    expect(d.merchant, 'SANCHA');
    expect(d.date, '2026-09-08');
    expect(d.time, '19:21');
    expect(d.total, 16000);
    expect(d.discount, 16000);
    expect(d.subtotal, 32000);
    expect(d.payment, 'QRIS');
    expect(d.items.length, 1);
    expect(d.items.first.name, 'Da Hong Pao Milk Tea (M)');
    expect(d.items.first.price, 32000);
  });

  test('toReceiptData menggabung tanggal + jam dan membawa diskon', () {
    final back = AiDraft.fromReceiptData(data).toReceiptData();
    expect(back.amount, 16000);
    expect(back.date, DateTime(2026, 9, 8, 19, 21));
    expect(back.voucher, 16000);
    expect(back.time, '19:21');
    expect(back.payType, 'QRIS');
    expect(back.lineItems.length, 1);
  });

  test('draft AI server (tanpa jam/diskon) tetap aman', () {
    const d = AiDraft(merchant: 'X', date: '2026-10-01', total: 5000);
    final back = d.toReceiptData();
    expect(back.date, DateTime(2026, 10, 1));
    expect(back.time, isNull);
    expect(back.voucher, isNull);
  });
}
