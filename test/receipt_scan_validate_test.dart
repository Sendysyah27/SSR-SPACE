import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/receipt_scan_validate.dart';

// Batch 284 tahap A: validator konsistensi struk (aturan ala Ollo).
// Semua kasus murni atas validateReceiptFigures + merchantHistoryFromTotals.

bool _has(List<ReceiptWarning> ws, String code) =>
    ws.any((w) => w.code == code);

void main() {
  group('merchantHistoryFromTotals', () {
    test('kosong / nol semua -> null', () {
      expect(merchantHistoryFromTotals(const []), isNull);
      expect(merchantHistoryFromTotals(const [0, -5]), isNull);
    });

    test('satu nilai', () {
      final h = merchantHistoryFromTotals(const [42000])!;
      expect(h.count, 1);
      expect(h.median, 42000);
      expect(h.max, 42000);
    });

    test('median ganjil + max dari daftar tak terurut', () {
      final h = merchantHistoryFromTotals(const [30000, 10000, 20000])!;
      expect(h.count, 3);
      expect(h.median, 20000);
      expect(h.max, 30000);
    });

    test('median genap = rata-rata dua tengah', () {
      final h = merchantHistoryFromTotals(const [10000, 20000, 30000, 40000])!;
      expect(h.median, 25000);
    });
  });

  group('subtotal_greater_than_total', () {
    test('positif: subtotal jauh di atas total', () {
      final ws = validateReceiptFigures(total: 100000, subtotal: 120000);
      expect(_has(ws, 'subtotal_greater_than_total'), isTrue);
    });

    test('negatif: subtotal di bawah total', () {
      final ws = validateReceiptFigures(total: 100000, subtotal: 90000);
      expect(_has(ws, 'subtotal_greater_than_total'), isFalse);
    });

    test('dalam toleransi pembulatan -> diam', () {
      // tol = max(500, 0,5% x 100000) = 500; 100400 <= 100500.
      final ws = validateReceiptFigures(total: 100000, subtotal: 100400);
      expect(_has(ws, 'subtotal_greater_than_total'), isFalse);
    });

    test('subtotal null -> pakai jumlah item', () {
      final ws = validateReceiptFigures(
        total: 50000,
        items: const [
          (name: 'A', price: 40000.0),
          (name: 'B', price: 30000.0),
        ],
      );
      expect(_has(ws, 'subtotal_greater_than_total'), isTrue);
    });
  });

  group('tax_subtotal_mismatch', () {
    test('positif: subtotal + pajak jauh dari total', () {
      final ws = validateReceiptFigures(
        total: 100000,
        subtotal: 100000,
        tax: 11000,
      );
      expect(_has(ws, 'tax_subtotal_mismatch'), isTrue);
    });

    test('negatif: subtotal + pajak == total', () {
      final ws = validateReceiptFigures(
        total: 111000,
        subtotal: 100000,
        tax: 11000,
      );
      expect(_has(ws, 'tax_subtotal_mismatch'), isFalse);
    });

    test('voucher menutup selisih -> diam', () {
      final ws = validateReceiptFigures(
        total: 101000,
        subtotal: 100000,
        tax: 11000,
        voucher: 10000,
      );
      expect(_has(ws, 'tax_subtotal_mismatch'), isFalse);
    });

    test('pajak 0 -> aturan mati', () {
      final ws = validateReceiptFigures(
        total: 100000,
        subtotal: 90000,
        tax: 0,
      );
      expect(_has(ws, 'tax_subtotal_mismatch'), isFalse);
    });
  });

  group('item_exceeds_total', () {
    test('item di atas total -> warning + itemName', () {
      final ws = validateReceiptFigures(
        total: 100000,
        items: const [(name: 'TV LED', price: 150000.0)],
      );
      final w = ws.where((e) => e.code == 'item_exceeds_total').toList();
      expect(w, hasLength(1));
      expect(w.first.itemName, 'TV LED');
    });

    test('item normal -> diam', () {
      final ws = validateReceiptFigures(
        total: 100000,
        items: const [(name: 'Kopi', price: 25000.0)],
      );
      expect(_has(ws, 'item_exceeds_total'), isFalse);
    });
  });

  group('amount_exceeds_merchant_range', () {
    final hist = merchantHistoryFromTotals(const [20000, 21000, 19000]);

    test('total 5x median -> warning', () {
      final ws = validateReceiptFigures(total: 100000, history: hist);
      expect(_has(ws, 'amount_exceeds_merchant_range'), isTrue);
    });

    test('riwayat < 3 -> aturan mati', () {
      final h2 = merchantHistoryFromTotals(const [20000, 21000]);
      final ws = validateReceiptFigures(total: 100000, history: h2);
      expect(_has(ws, 'amount_exceeds_merchant_range'), isFalse);
    });

    test('total masih dalam rentang -> diam', () {
      final ws = validateReceiptFigures(total: 50000, history: hist);
      expect(_has(ws, 'amount_exceeds_merchant_range'), isFalse);
    });
  });

  group('merchant_amount_caps', () {
    test('di atas 2x max riwayat -> warning', () {
      final hist =
          merchantHistoryFromTotals(const [30000, 28000, 29000, 30000, 27000]);
      final ws = validateReceiptFigures(total: 200000, history: hist);
      expect(_has(ws, 'merchant_amount_caps'), isTrue);
    });

    test('caps statis tanpa riwayat: 300 juta -> warning', () {
      final ws = validateReceiptFigures(total: 300000000);
      expect(_has(ws, 'merchant_amount_caps'), isTrue);
    });

    test('total normal -> diam', () {
      final ws = validateReceiptFigures(total: 85000);
      expect(ws, isEmpty);
    });
  });

  test('total <= 0 -> selalu kosong', () {
    expect(validateReceiptFigures(total: 0, subtotal: 100), isEmpty);
    expect(validateReceiptFigures(total: -5), isEmpty);
  });
}
