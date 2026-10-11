import 'package:excel_plus/excel_plus.dart';

import '../models/transaction.dart';

// Ekspor Laporan ke .xlsx: 1 sheet Transaksi + filter + judul beku.
// Kolom identik CSV (tanggal, jenis, nominal, dompet, ke_dompet,
// kategori, catatan); nominal ditulis ANGKA supaya bisa SUM di Excel.

/// Nama sheet data.
const xlsxSheetName = 'Transaksi';

/// Header kolom (identik CSV).
const xlsxHeader = [
  'tanggal',
  'jenis',
  'nominal',
  'dompet',
  'ke_dompet',
  'kategori',
  'catatan',
];

/// Rakit workbook .xlsx dari item terfilter. Null → string kosong.
/// Kembalikan bytes siap tulis, null bila encode gagal.
List<int>? buildReportXlsx(
  List<SaasTransaction> items,
  Map<String, String> walletNames,
) {
  final excel = Excel.createExcel();
  excel.rename(excel.getDefaultSheet() ?? 'Sheet1', xlsxSheetName);
  final sheet = excel[xlsxSheetName];
  sheet.appendRow([for (final h in xlsxHeader) TextCellValue(h)]);
  for (final t in items) {
    final amount = t.amount;
    sheet.appendRow([
      TextCellValue(t.date ?? ''),
      TextCellValue(t.type),
      amount % 1 == 0
          ? IntCellValue(amount.toInt())
          : DoubleCellValue(amount),
      TextCellValue(walletNames[t.walletId] ?? ''),
      TextCellValue(walletNames[t.toWalletId] ?? ''),
      TextCellValue(t.category ?? ''),
      TextCellValue(t.note ?? ''),
    ]);
  }
  final lastRow = items.length + 1;
  sheet.setAutoFilter(
    CellIndex.indexByString('A1'),
    CellIndex.indexByString('G$lastRow'),
  );
  sheet.freezePanes(rows: 1);
  return excel.save();
}
