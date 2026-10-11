import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/report_xlsx.dart';

SaasTransaction _tx({
  String id = 't1',
  String type = 'out',
  double amount = 50000,
  String? walletId = 'w1',
  String? toWalletId,
  String? category = 'Makan',
  String? note = 'Siang',
  String? date = '2026-10-01',
}) => SaasTransaction(
  id: id,
  orgId: 'o1',
  type: type,
  amount: amount,
  walletId: walletId,
  toWalletId: toWalletId,
  category: category,
  note: note,
  date: date,
);

Excel _book(List<int> bytes) => Excel.decodeBytes(bytes);

/// Baris header template selalu indeks 3 (judul 0, meta 1, kosong 2).
Sheet _sheet(List<int> bytes) => _book(bytes).tables['Transaksi']!;

void main() {
  test('template: judul merge + 8 kolom header', () {
    final bytes = buildReportXlsx([], {}, metaLine: 'Oktober 2026')!;
    final sheet = _sheet(bytes);
    expect(sheet.maxColumns, 8);
    final merged = sheet.getMergedCells('Transaksi');
    expect(merged.any((s) => s.contains('A1') && s.contains('H1')), isTrue);
    final headRow = sheet.rows.firstWhere(
      (r) => r.any((c) => '${c?.value}'.contains('Tanggal')),
    );
    final head = headRow.map((c) => '${c?.value}').join('|');
    expect(head, contains('Dari'));
    expect(head, contains('Catatan'));
    expect('${sheet.rows.first.first?.value}', contains('SSR SPACE'));
  });

  test('baris + nominal numerik + Dari/Ke transfer', () {
    final bytes = buildReportXlsx(
      [
        _tx(),
        _tx(
          id: 't2',
          type: 'transfer',
          amount: 1500,
          toWalletId: 'w2',
          category: null,
          note: null,
        ),
      ],
      {'w1': 'Kas', 'w2': 'DANA'},
      metaLine: 'Oktober 2026',
    )!;
    final maps = _sheet(bytes).rowsAsMaps(headerRow: 3);
    // 2 data + 1 TOTAL.
    expect(maps.length, 3);
    expect(maps[0]['Nominal'], 50000);
    expect(maps[0]['Nominal'] is num, isTrue);
    expect(maps[0]['Dompet'], 'Kas');
    expect(maps[0]['Dari'], 'Kas');
    expect(maps[0]['Ke'], '');
    expect(maps[1]['Dari'], 'Kas');
    expect(maps[1]['Ke'], 'DANA');
    expect(maps[2]['Tanggal'], 'TOTAL KELUAR');
    expect(maps[2]['Nominal'], 50000);
  });

  test('autofilter + freeze di baris header', () {
    final bytes = buildReportXlsx([_tx(), _tx(id: 't2')], {})!;
    final sheet = _sheet(bytes);
    expect(sheet.autoFilter, 'A4:H6');
    expect(sheet.frozenRows, 4);
  });

  test('null semua tak throw + TOTAL ikut', () {
    final bytes = buildReportXlsx(
      [_tx(walletId: null, category: null, note: null, date: null)],
      {},
    )!;
    final maps = _sheet(bytes).rowsAsMaps(headerRow: 3);
    expect(maps.length, 2);
    expect(maps[0]['Tanggal'], '');
    expect(maps[1]['Nominal'], 50000);
  });

  test('lebar kolom ikut isi + tanggal full', () {
    final bytes = buildReportXlsx(
      [
        _tx(
          note:
              'Otomatis dari SeaBank, digabung sebagai transfer ke BCA jelas',
        ),
      ],
      {'w1': 'Kas'},
    )!;
    final sheet = _sheet(bytes);
    expect(sheet.getColumnWidth(0), 13);
    expect(sheet.getColumnWidth(7), 50);
    final maps = sheet.rowsAsMaps(headerRow: 3);
    expect('${maps[0]['Tanggal']}', contains('2026-10-01'));
  });
}
