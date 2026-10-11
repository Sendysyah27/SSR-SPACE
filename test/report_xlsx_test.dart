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

void main() {
  test('sheet Transaksi + header 7 kolom, kosong tetap valid', () {
    final bytes = buildReportXlsx([], {})!;
    final sheet = _book(bytes).tables['Transaksi']!;
    expect(sheet.maxColumns, 7);
    final head = sheet.rows.first.map((c) => '${c?.value}').join('|');
    expect(head, contains('tanggal'));
    expect(head, contains('ke_dompet'));
  });

  test('baris + nominal numerik (bukan string)', () {
    final bytes = buildReportXlsx(
      [
        _tx(),
        _tx(
          id: 't2',
          type: 'in',
          amount: 1500.5,
          walletId: null,
          category: null,
          note: null,
        ),
      ],
      {'w1': 'Kas'},
    )!;
    final maps = _book(bytes).tables['Transaksi']!.rowsAsMaps();
    expect(maps.length, 2);
    expect(maps[0]['nominal'], 50000);
    expect(maps[0]['nominal'] is num, isTrue);
    expect(maps[0]['dompet'], 'Kas');
    expect(maps[0]['kategori'], 'Makan');
    expect(maps[1]['nominal'], 1500.5);
    expect(maps[1]['dompet'], '');
    expect(maps[1]['kategori'], '');
  });

  test('autofilter + freeze baris judul', () {
    final bytes = buildReportXlsx([_tx(), _tx(id: 't2')], {})!;
    final sheet = _book(bytes).tables['Transaksi']!;
    expect(sheet.autoFilter, 'A1:G3');
    expect(sheet.frozenRows, 1);
  });

  test('null semua tak throw', () {
    final bytes = buildReportXlsx(
      [_tx(walletId: null, category: null, note: null, date: null)],
      {},
    )!;
    final maps = _book(bytes).tables['Transaksi']!.rowsAsMaps();
    expect(maps.length, 1);
    expect(maps[0]['tanggal'], '');
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
    final sheet = _book(bytes).tables['Transaksi']!;
    expect(sheet.getColumnWidth(0), 13);
    expect(sheet.getColumnWidth(6), 50);
    final maps = sheet.rowsAsMaps();
    expect('${maps[0]['tanggal']}', contains('2026-10-01'));
  });
}
