import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/receipt_scan_parse.dart';

const _cats = <String>[
  'Makanan',
  'Transportasi',
  'Belanja',
  'Tagihan',
  'Kesehatan',
  'Pendidikan',
  'Hiburan',
  'Pulsa & Internet',
  'Tabungan',
  'Lainnya',
];

void main() {
  group('parseReceiptScanJson', () {
    test('JSON valid -> parse benar (Sancha: total 16000 bukan 32000)', () {
      final r = parseReceiptScanJson(
        '{"merchant":"SANCHA","date":"2026-09-08","total":16000,"category":"Makanan"}',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.merchant, 'SANCHA');
      expect(r.date, '2026-09-08');
      expect(r.total, 16000);
      expect(r.category, 'Makanan');
    });

    test('JSON dalam fence ```json tetap terbaca', () {
      final r = parseReceiptScanJson(
        '```json\n{"merchant":"Toko A","date":"2026-10-01","total":5000,"category":"Belanja"}\n```',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.total, 5000);
    });

    test('JSON rusak -> null dengan aman', () {
      expect(parseReceiptScanJson('{bukan json', _cats), isNull);
      expect(parseReceiptScanJson('', _cats), isNull);
      expect(parseReceiptScanJson('[1,2,3]', _cats), isNull);
      expect(parseReceiptScanJson('halo', _cats), isNull);
    });

    test('total 0 / negatif -> ditolak', () {
      expect(
        parseReceiptScanJson(
          '{"merchant":"A","date":"2026-10-01","total":0,"category":"Makanan"}',
          _cats,
        ),
        isNull,
      );
      expect(
        parseReceiptScanJson(
          '{"merchant":"A","date":"2026-10-01","total":-5000,"category":"Makanan"}',
          _cats,
        ),
        isNull,
      );
    });

    test('total double / string -> ditolak', () {
      expect(
        parseReceiptScanJson(
          '{"merchant":"A","date":"2026-10-01","total":16000.0,"category":"Makanan"}',
          _cats,
        ),
        isNull,
      );
      expect(
        parseReceiptScanJson(
          '{"merchant":"A","date":"2026-10-01","total":"16000","category":"Makanan"}',
          _cats,
        ),
        isNull,
      );
    });

    test('tanggal invalid -> ditolak', () {
      expect(
        parseReceiptScanJson(
          '{"merchant":"A","date":"2026-13-01","total":5000,"category":"Makanan"}',
          _cats,
        ),
        isNull,
      );
      expect(
        parseReceiptScanJson(
          '{"merchant":"A","date":"08-09-2026","total":5000,"category":"Makanan"}',
          _cats,
        ),
        isNull,
      );
      expect(
        parseReceiptScanJson(
          '{"merchant":"A","date":"2026-02-30","total":5000,"category":"Makanan"}',
          _cats,
        ),
        isNull,
      );
    });

    test('kategori tak dikenal -> ditolak; tak sensitif huruf diterima', () {
      expect(
        parseReceiptScanJson(
          '{"merchant":"A","date":"2026-10-01","total":5000,"category":"Jajan"}',
          _cats,
        ),
        isNull,
      );
      final r = parseReceiptScanJson(
        '{"merchant":"A","date":"2026-10-01","total":5000,"category":"makanan"}',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.category, 'Makanan');
    });

    test('merchant kosong -> tetap valid (opsional)', () {
      final r = parseReceiptScanJson(
        '{"merchant":"","date":"2026-10-01","total":5000,"category":"Lainnya"}',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.merchant, isNull);
      expect(r.category, 'Lainnya');
    });
  });

  group('scanReceiptSystemPrompt', () {
    test('memuat kunci JSON dan daftar kategori', () {
      final p = scanReceiptSystemPrompt(_cats);
      expect(p.contains('"merchant"'), isTrue);
      expect(p.contains('"total"'), isTrue);
      expect(p.contains('Makanan'), isTrue);
    });
  });
}
