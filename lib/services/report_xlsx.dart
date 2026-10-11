import 'package:excel_plus/excel_plus.dart';

import '../models/transaction.dart';
import 'xlsx_layout.dart';

// Ekspor Laporan ke .xlsx: 1 sheet Transaksi + filter + judul beku.
// Kolom identik CSV (tanggal, jenis, nominal, dompet, ke_dompet,
// kategori, catatan); nominal ditulis ANGKA berformat ribuan supaya
// bisa SUM; tanggal sel date full; header tebal + latar; lebar kolom
// menyesuaikan isi; baris judul lebih tinggi (padding).

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

/// Lebar minimum per kolom (tanggal full 11 char, nominal ber-separator).
const _minWidths = [13.0, 10.0, 14.0, 12.0, 12.0, 16.0, 20.0];

CellStyle _headerStyle() => CellStyle(
  bold: true,
  backgroundColorHex: ExcelColor.teal700,
  fontColorHex: ExcelColor.white,
);

CellStyle _textStyle() => CellStyle(indent: 1);

CellStyle _dateStyle() => CellStyle(
  numberFormat: NumFormat.custom(formatCode: 'DD MMM YYYY'),
  indent: 1,
);

CellStyle _numStyle(bool decimal) => CellStyle(
  numberFormat: decimal ? NumFormat.standard_4 : NumFormat.standard_3,
  indent: 1,
);

/// Rakit workbook .xlsx dari item terfilter. Null → string kosong.
/// Kembalikan bytes siap tulis, null bila encode gagal.
List<int>? buildReportXlsx(
  List<SaasTransaction> items,
  Map<String, String> walletNames,
) {
  final excel = Excel.createExcel();
  excel.rename(excel.getDefaultSheet() ?? 'Sheet1', xlsxSheetName);
  final sheet = excel[xlsxSheetName];
  final hs = _headerStyle();
  final ts = _textStyle();
  final ds = _dateStyle();
  for (var c = 0; c < xlsxHeader.length; c++) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(c, 0),
      TextCellValue(xlsxHeader[c]),
      cellStyle: hs,
    );
  }
  final colText = List.generate(
    xlsxHeader.length,
    (c) => <String>[xlsxHeader[c]],
  );
  var r = 1;
  for (final t in items) {
    final rawDate = t.date ?? '';
    final dt = rawDate.length >= 10
        ? DateTime.tryParse(rawDate.substring(0, 10))
        : null;
    final dec = t.amount % 1 != 0;
    final dompet = walletNames[t.walletId] ?? '';
    final keDompet = walletNames[t.toWalletId] ?? '';
    final kategori = t.category ?? '';
    final catatan = t.note ?? '';
    sheet.updateCell(
      CellIndex.indexByColumnRow(0, r),
      dt == null ? TextCellValue('') : DateCellValue.fromDateTime(dt),
      cellStyle: ds,
    );
    sheet.updateCell(
      CellIndex.indexByColumnRow(1, r),
      TextCellValue(t.type),
      cellStyle: ts,
    );
    sheet.updateCell(
      CellIndex.indexByColumnRow(2, r),
      dec ? DoubleCellValue(t.amount) : IntCellValue(t.amount.toInt()),
      cellStyle: _numStyle(dec),
    );
    sheet.updateCell(
      CellIndex.indexByColumnRow(3, r),
      TextCellValue(dompet),
      cellStyle: ts,
    );
    sheet.updateCell(
      CellIndex.indexByColumnRow(4, r),
      TextCellValue(keDompet),
      cellStyle: ts,
    );
    sheet.updateCell(
      CellIndex.indexByColumnRow(5, r),
      TextCellValue(kategori),
      cellStyle: ts,
    );
    sheet.updateCell(
      CellIndex.indexByColumnRow(6, r),
      TextCellValue(catatan),
      cellStyle: ts,
    );
    colText[0].add(rawDate);
    colText[1].add(t.type);
    colText[2].add(t.amount.toStringAsFixed(dec ? 2 : 0));
    colText[3].add(dompet);
    colText[4].add(keDompet);
    colText[5].add(kategori);
    colText[6].add(catatan);
    r++;
  }
  for (var c = 0; c < xlsxHeader.length; c++) {
    sheet.setColumnWidth(c, xlsxFitWidth(colText[c], min: _minWidths[c]));
  }
  sheet.setRowHeight(0, 22);
  final lastRow = items.length + 1;
  sheet.setAutoFilter(
    CellIndex.indexByString('A1'),
    CellIndex.indexByString('G$lastRow'),
  );
  sheet.freezePanes(rows: 1);
  return excel.save();
}
