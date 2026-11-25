import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/nine_prompts.dart';
import 'package:ssr_space/services/receipt_scan_parse.dart';

const _cats = defaultReceiptCategories;

void main() {
  group('receiptCategoriesFor', () {
    test('bawaan saja bila tanpa tambahan', () {
      expect(receiptCategoriesFor(const []), _cats);
    });

    test('tambah kategori lapis atas, tanpa duplikat huruf, cap 20', () {
      final out = receiptCategoriesFor([
        'Kopi > Latte',
        'makanan',
        'Servis Motor',
        for (var i = 0; i < 30; i++) 'Extra $i',
      ]);
      expect(out.contains('Kopi'), isTrue);
      expect(out.contains('Servis Motor'), isTrue);
      expect(out.length, 20);
      final makan = out.where((c) => c.toLowerCase() == 'makanan').toList();
      expect(makan.length, 1);
    });
  });

  group('receiptSystemPrompt', () {
    test('memuat format baris + daftar kategori', () {
      final p = receiptSystemPrompt(_cats);
      expect(p.contains('MERCHANT: Nama Gerai'), isTrue);
      expect(p.contains('TOTAL: 16000'), isTrue);
      expect(p.contains('Makanan, Transportasi'), isTrue);
      expect(p.contains('Jangan pakai tool'), isTrue);
      expect(p.contains('merchant":'), isFalse);
    });
  });

  group('normalizeReceiptContract', () {
    test('format baris -> JSON ketat yang lolos parseReceiptScanJson', () {
      const raw =
          'MERCHANT: Indomaret\nDATE: 2026-09-08\nTOTAL: 16000\n'
          'CATEGORY: Makanan\nITEMS:\n'
          'Racik Bumbu 33gr | 1 | 1700\n'
          'Sasa Santan 65ml | 2 | 9000\n';
      final out = normalizeReceiptContract(raw, _cats);
      final json = jsonDecode(out) as Map<String, dynamic>;
      expect(json['total'], 16000);
      expect(json['date'], '2026-09-08');
      expect(json['category'], 'Makanan');
      expect((json['items'] as List).length, 2);
      final parsed = parseReceiptScanJson(out, _cats);
      expect(parsed, isNotNull);
      expect(parsed!.total, 16000);
    });

    test('JSON dibungkus prosa + fence tetap diekstrak', () {
      const raw =
          'Ini hasilnya:\n```json\n'
          '{"merchant":"Sancha","date":"2026-09-08","total":32000,'
          '"category":"Makanan","items":[{"name":"Kopi","qty":2,'
          '"price":32000}]}\n```\nSemoga membantu.';
      final out = normalizeReceiptContract(raw, _cats);
      final parsed = parseReceiptScanJson(out, _cats);
      expect(parsed, isNotNull);
      expect(parsed!.merchant, 'Sancha');
      expect(parsed.items.single.qty, 2);
    });

    test('kategori di luar daftar -> Lainnya', () {
      const raw =
          '{"merchant":null,"date":"2026-09-08","total":5000,'
          '"category":"Servis Motor","items":[]}';
      final json = jsonDecode(normalizeReceiptContract(raw, _cats)) as Map;
      expect(json['category'], 'Lainnya');
    });

    test('total 0 / tanggal mustahil / tanpa kategori -> teks asli', () {
      const bad1 = '{"date":"2026-09-08","total":0,"category":"Makanan"}';
      const bad2 = '{"date":"2026-02-30","total":5000,"category":"Makanan"}';
      const bad3 = '{"date":"2026-09-08","total":5000}';
      expect(normalizeReceiptContract(bad1, _cats), bad1);
      expect(normalizeReceiptContract(bad2, _cats), bad2);
      expect(normalizeReceiptContract(bad3, _cats), bad3);
    });

    test('total double utuh diterima sebagai int', () {
      const raw =
          '{"date":"2026-09-08","total":16000.0,'
          '"category":"Belanja"}';
      final json = jsonDecode(normalizeReceiptContract(raw, _cats)) as Map;
      expect(json['total'], 16000);
    });
  });

  group('normalizeChatContract', () {
    test('kontrak di dalam prosa -> JSON bersih tanpa **', () {
      const raw =
          'Oke, ini catatannya:\n'
          '{"reply":"**Siap**, sudah kucatat ya","action":{"type":"out",'
          '"amount":15000}}\nSemoga membantu.';
      final json =
          jsonDecode(normalizeChatContract(raw)) as Map<String, dynamic>;
      expect(json['reply'], 'Siap, sudah kucatat ya');
      expect((json['action'] as Map)['amount'], 15000);
    });

    test('tanpa kontrak -> teks asli (bukan dibungkus paksa)', () {
      const raw = 'Halo! Ada yang bisa dibantu?';
      expect(normalizeChatContract(raw), raw);
    });

    test('reply kosong -> teks asli', () {
      const raw = '{"reply":"   ","action":null}';
      expect(normalizeChatContract(raw), raw);
    });
  });
}
