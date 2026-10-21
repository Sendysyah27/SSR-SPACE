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

  group('scanReceiptJsonPrompt (tahap E)', () {
    test('meminta JSON ketat; daftar kategori TIDAK disuntikkan', () {
      final p = scanReceiptJsonPrompt();
      expect(p.contains('"total"'), isTrue);
      expect(p.contains('"items"'), isTrue);
      expect(p.contains('Transportasi'), isFalse);
      expect(p.contains('Pulsa & Internet'), isFalse);
    });
  });

  group('parseReceiptScanJson fixture EF (tahap E)', () {
    test('JSON ketat keluaran EF terparse penuh', () {
      final r = parseReceiptScanJson(
        '{"merchant":"Indomaret","date":"2026-10-21","total":48500,'
        '"category":"Belanja","items":[{"name":"Susu UHT 1L","qty":1,"price":21000},'
        '{"name":"Roti Tawar","qty":1,"price":27500}]}',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.total, 48500);
      expect(r.items.length, 2);
    });

    test('keluaran berantakan: prosa + fence tetap terbaca (ekstraksi)', () {
      final r = parseReceiptScanJson(
        'Berikut hasilnya:\n```json\n{"merchant":"A","date":"2026-10-01",'
        '"total":5000,"category":"Belanja","items":[]}\n```\nsemoga membantu',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.total, 5000);
    });

    test('JSON pretty multi-baris terparse', () {
      final r = parseReceiptScanJson(
        '{\n  "merchant": "A",\n  "date": "2026-10-01",\n  "total": 7000,\n'
        '  "category": "Makanan",\n  "items": []\n}',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.total, 7000);
    });
  });

  group('parseReceiptScanJson items', () {
    test('items lengkap -> terparse semua', () {
      final r = parseReceiptScanJson(
        '{"merchant":"SANCHA","date":"2026-09-08","total":32000,"category":"Makanan",'
        '"items":[{"name":"Da Hong Pao Milk Tea","qty":2,"price":32000},{"name":"Kantong","price":0}]}',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.items.length, 2);
      expect(r.items[0].name, 'Da Hong Pao Milk Tea');
      expect(r.items[0].qty, 2);
      expect(r.items[0].price, 32000);
      expect(r.items[1].qty, 1); // default bila tak disebut
      expect(r.items[1].price, 0);
    });

    test('tanpa items -> tetap valid, list kosong', () {
      final r = parseReceiptScanJson(
        '{"merchant":"A","date":"2026-10-01","total":5000,"category":"Belanja"}',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.items, isEmpty);
    });

    test('item tak valid dilewati, hasil tetap valid', () {
      final r = parseReceiptScanJson(
        '{"merchant":"A","date":"2026-10-01","total":5000,"category":"Belanja",'
        '"items":[{"name":"","price":100},{"name":"X","price":"100"},'
        '{"name":"Bagus","qty":3,"price":3000},42]}',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.items.length, 1);
      expect(r.items[0].name, 'Bagus');
      expect(r.items[0].qty, 3);
    });

    test('items bukan list -> list kosong', () {
      final r = parseReceiptScanJson(
        '{"merchant":"A","date":"2026-10-01","total":5000,"category":"Belanja","items":"x"}',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.items, isEmpty);
    });
  });

  group('receiptDetailText', () {
    test('ada marker + total', () {
      const r = ReceiptScanResult(
        merchant: 'Toko ABC',
        date: '2026-09-08',
        total: 16000,
        category: 'Makanan',
        items: [
          ReceiptScanItem(
              name: 'Racik Bumbu Sayur Asem 33gr', qty: 1, price: 1700),
          ReceiptScanItem(
              name: 'Sasa Santan Kelapa Cair 65ml', qty: 2, price: 9000),
        ],
      );
      final d = receiptDetailText(r);
      expect(d.startsWith('[STRUK]'), isTrue);
      expect(d.contains('TOTAL Rp 16.000'), isTrue);
      expect(isReceiptDetailNote(d), isTrue);
      expect(isReceiptDetailNote('catatan biasa'), isFalse);
    });
  });
}
