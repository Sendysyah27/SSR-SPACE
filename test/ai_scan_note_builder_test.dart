import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/ai_scan_note_builder.dart';
import 'package:ssr_space/services/receipt_parse.dart';

// Batch 284 tahap C: NoteBuilder catatan scan — susunan potongan,
// urutan kustom, saklar, pencocokan nama pemilik.

void main() {
  group('sanitizeAiScanNoteOrder', () {
    test('null / kosong -> bawaan', () {
      expect(sanitizeAiScanNoteOrder(null), defaultAiScanNoteOrder);
    });

    test('kunci asing dibuang, duplikat dibuang', () {
      expect(
        sanitizeAiScanNoteOrder(['total', 'ngawur', 'total', 'merchant']),
        ['total', 'merchant', 'datetime', 'items', 'owner'],
      );
    });

    test('potongan hilang ditambah di akhir', () {
      expect(
        sanitizeAiScanNoteOrder(['owner']),
        ['owner', 'merchant', 'datetime', 'items', 'total'],
      );
    });
  });

  group('buildAiScanNote', () {
    const full = {
      'merchant': 'Kopi Kenangan',
      'dateTimeText': '2026-10-21 09:15',
      'itemsText': '1. Kopi Susu — Rp 25.000',
      'totalText': 'TOTAL Rp 25.000',
    };

    test('urutan bawaan lengkap', () {
      final note = buildAiScanNote(
        order: defaultAiScanNoteOrder,
        merchant: full['merchant'],
        dateTimeText: full['dateTimeText'],
        itemsText: full['itemsText'],
        totalText: full['totalText'],
      );
      expect(
        note,
        '[STRUK] Kopi Kenangan\n2026-10-21 09:15\n1. Kopi Susu — Rp 25.000\nTOTAL Rp 25.000',
      );
    });

    test('urutan kustom: total di depan', () {
      final note = buildAiScanNote(
        order: const ['total', 'merchant'],
        merchant: full['merchant'],
        dateTimeText: full['dateTimeText'],
        itemsText: full['itemsText'],
        totalText: full['totalText'],
      );
      expect(note.split('\n').first, 'TOTAL Rp 25.000');
      expect(note.contains('Kopi Kenangan'), isTrue);
    });

    test('potongan kosong dilewati', () {
      final note = buildAiScanNote(
        order: defaultAiScanNoteOrder,
        totalText: 'TOTAL Rp 10.000',
      );
      expect(note, 'TOTAL Rp 10.000');
    });

    test('pemilik tampil hanya bila nama muncul di teks struk', () {
      final cocok = buildAiScanNote(
        order: defaultAiScanNoteOrder,
        merchant: 'Transfer',
        ownerName: 'Sendy Syah',
        sourceText: 'Pengirim: SENDY SYAH RAMADHAN\nNominal 50000',
      );
      expect(cocok.contains('Pemilik: Sendy Syah'), isTrue);

      final takCocok = buildAiScanNote(
        order: defaultAiScanNoteOrder,
        merchant: 'Transfer',
        ownerName: 'Sendy Syah',
        sourceText: 'Pengirim: BUDI SANTOSO\nNominal 50000',
      );
      expect(takCocok.contains('Pemilik:'), isFalse);
    });

    test('nama pemilik kosong -> potongan pemilik mati', () {
      final note = buildAiScanNote(
        order: defaultAiScanNoteOrder,
        merchant: 'Transfer',
        ownerName: '',
        sourceText: 'apa pun',
      );
      expect(note.contains('Pemilik:'), isFalse);
    });
  });

  group('settings simpan/muat', () {
    test('saklar mati tersimpan', () async {
      SharedPreferences.setMockInitialValues({});
      await saveAiScanNoteSettings(const AiScanNoteSettings(enabled: false));
      final st = await loadAiScanNoteSettings();
      expect(st.enabled, isFalse);
    });

    test('urutan + pemilik tersimpan', () async {
      SharedPreferences.setMockInitialValues({});
      await saveAiScanNoteSettings(const AiScanNoteSettings(
        order: ['total', 'merchant'],
        ownerName: 'Sendy Syah',
      ));
      final st = await loadAiScanNoteSettings();
      expect(st.order.first, 'total');
      expect(st.ownerName, 'Sendy Syah');
    });
  });

  group('buildScanNoteFor', () {
    final data = ReceiptData(
      amount: 25000,
      date: DateTime(2026, 10, 21),
      merchant: 'Kopi Kenangan',
      items: const ['Kopi Susu'],
      lineItems: const [
        ReceiptItem(name: 'Kopi Susu', qty: 1, price: 25000),
      ],
      confident: true,
    );

    test('menyala -> catatan terstruktur dari ReceiptData', () async {
      SharedPreferences.setMockInitialValues({});
      final note = await buildScanNoteFor(data);
      expect(note, isNotNull);
      expect(note!.startsWith('[STRUK] Kopi Kenangan'), isTrue);
      expect(note.contains('2026-10-21'), isTrue);
      expect(note.contains('1. Kopi Susu — Rp 25.000'), isTrue);
      expect(note.contains('TOTAL Rp 25.000'), isTrue);
    });

    test('saklar mati -> string kosong (catatan dikosongkan)', () async {
      SharedPreferences.setMockInitialValues({
        'ai_scan_note_enabled': false,
      });
      final note = await buildScanNoteFor(data);
      expect(note, '');
    });

    test('urutan kustom dari prefs diikuti', () async {
      SharedPreferences.setMockInitialValues({
        'ai_scan_note_order': ['total', 'merchant'],
      });
      final note = await buildScanNoteFor(data);
      expect(note!.split('\n').first, 'TOTAL Rp 25.000');
    });
  });
}
