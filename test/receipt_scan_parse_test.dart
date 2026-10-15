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

    test('meminta daftar item lengkap (bukan ringkasan)', () {
      final p = scanReceiptSystemPrompt(_cats);
      expect(p.contains('"items"'), isTrue);
      expect(p.contains('SEMUA baris produk'), isTrue);
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

  group('parseReceiptScanText (format baris)', () {
    const txt = 'MERCHANT: Toko ABC\n'
        'DATE: 2026-09-08\n'
        'TOTAL: 16000\n'
        'CATEGORY: Makanan\n'
        'ITEMS:\n'
        'Racik Bumbu Sayur Asem 33gr | 1 | 1700\n'
        'Sasa Santan Kelapa Cair 65ml | 2 | 9000\n';

    test('format normal -> parse benar', () {
      final r = parseReceiptScanText(txt, _cats);
      expect(r, isNotNull);
      expect(r!.merchant, 'Toko ABC');
      expect(r.date, '2026-09-08');
      expect(r.total, 16000);
      expect(r.category, 'Makanan');
      expect(r.items.length, 2);
      expect(r.items[0].name, 'Racik Bumbu Sayur Asem 33gr');
      expect(r.items[0].qty, 1);
      expect(r.items[0].price, 1700);
      expect(r.items[1].qty, 2);
    });

    test('baris rusak di tengah -> dilewati, lainnya lolos', () {
      final r = parseReceiptScanText(
        'MERCHANT: X\nDATE: 2026-10-01\nTOTAL: 5000\nCATEGORY: Belanja\n'
        'ITEMS:\n'
        'Barang A | 1 | 2000\n'
        'BARIS RUSAK TANPA PIPA\n'
        'Barang B | 1 | 3000\n'
        'Barang C | | \n',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.items.length, 2);
      expect(r.items[0].name, 'Barang A');
      expect(r.items[1].name, 'Barang B');
    });

    test('lebih dari 100 item -> cap 100 + truncated', () {
      final buf = StringBuffer(
          'MERCHANT: X\nDATE: 2026-10-01\nTOTAL: 999999\nCATEGORY: Belanja\nITEMS:\n');
      for (var i = 1; i <= 105; i++) {
        buf.writeln('Item $i | 1 | 1000');
      }
      final r = parseReceiptScanText(buf.toString(), _cats);
      expect(r, isNotNull);
      expect(r!.items.length, 100);
      expect(r.truncatedItems, 5);
    });

    test('header tak valid -> null', () {
      expect(
          parseReceiptScanText(
              'MERCHANT: X\nDATE: 2026-10-01\nTOTAL: 0\nCATEGORY: Belanja\nITEMS:\n',
              _cats),
          isNull);
      expect(
          parseReceiptScanText(
              'MERCHANT: X\nDATE: 2026-13-99\nTOTAL: 5000\nCATEGORY: Belanja\nITEMS:\n',
              _cats),
          isNull);
      expect(
          parseReceiptScanText(
              'MERCHANT: X\nDATE: 2026-10-01\nTOTAL: 5000\nCATEGORY: Ngawur\nITEMS:\n',
              _cats),
          isNull);
      expect(parseReceiptScanText('', _cats), isNull);
    });

    test('TOTAL toleran format Indonesia', () {
      final r = parseReceiptScanText(
        'MERCHANT: X\nDATE: 2026-10-01\nTOTAL: 115.500\nCATEGORY: Belanja\nITEMS:\n',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.total, 115500);
    });

    test('tanpa section ITEMS -> header saja tetap valid', () {
      final r = parseReceiptScanText(
        'MERCHANT: X\nDATE: 2026-10-01\nTOTAL: 5000\nCATEGORY: Belanja\n',
        _cats,
      );
      expect(r, isNotNull);
      expect(r!.items, isEmpty);
    });

    test('receiptDetailText ada marker + total', () {
      final r = parseReceiptScanText(txt, _cats)!;
      final d = receiptDetailText(r);
      expect(d.startsWith('[STRUK]'), isTrue);
      expect(d.contains('TOTAL Rp16.000'), isTrue);
      expect(isReceiptDetailNote(d), isTrue);
      expect(isReceiptDetailNote('catatan biasa'), isFalse);
    });
  });
}
