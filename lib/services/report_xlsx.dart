import 'package:excel_plus/excel_plus.dart';

import '../models/transaction.dart';
import 'xlsx_layout.dart';

// Template .xlsx khusus SSR SPACE (Batch 19):
// - Baris 1: judul merge + besar bold warna brand.
// - Baris 2: periode + tanggal ekspor.
// - Baris 3: kosong pemisah.
// - Baris 4: header bold + latar + border semua sisi, freeze di sini.
// - Data dari baris 5; nominal angka ribuan; tanggal sel-date full;
//   border tipis semua sel data; zebra tipis; catatan wrap.
// - Baris terakhir: TOTAL KELUAR (jumlah belanja) + border tebal atas.
// Kolom: Tanggal | Jenis | Nominal | Dompet | Dari | Ke | Kategori
// | Catatan. Dari = dompet sumber (selalu), Ke = tujuan (transfer saja).

/// Nama sheet data.
const xlsxSheetName = 'Transaksi';

/// Judul template (brand, selalu Indonesia).
const xlsxTitle = 'LAPORAN KEUANGAN SSR SPACE';

/// Header kolom.
const xlsxHeader = [
  'Tanggal',
  'Jenis',
  'Nominal',
  'Dompet',
  'Dari',
  'Ke',
  'Kategori',
  'Catatan',
];

/// Lebar minimum per kolom.
const _minWidths = [13.0, 10.0, 14.0, 12.0, 12.0, 12.0, 16.0, 40.0];

Border _thin() => Border(borderStyle: BorderStyle.Thin);

Border _medium() => Border(borderStyle: BorderStyle.Medium);

CellStyle _headerStyle() {
  final b = _thin();
  return CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.teal700,
    fontColorHex: ExcelColor.white,
    leftBorder: b,
    rightBorder: b,
    topBorder: b,
    bottomBorder: b,
  );
}

CellStyle _titleStyle() => CellStyle(
  bold: true,
  fontSize: 16,
  fontColorHex: ExcelColor.teal700,
);

CellStyle _textStyle({bool zebra = false}) {
  final b = _thin();
  return CellStyle(
    indent: 1,
    backgroundColorHex: zebra ? ExcelColor.teal50 : ExcelColor.white,
    leftBorder: b,
    rightBorder: b,
    topBorder: b,
    bottomBorder: b,
  );
}

CellStyle _noteStyle({bool zebra = false}) {
  final b = _thin();
  return CellStyle(
    indent: 1,
    textWrapping: TextWrapping.wrapText,
    backgroundColorHex: zebra ? ExcelColor.teal50 : ExcelColor.white,
    leftBorder: b,
    rightBorder: b,
    topBorder: b,
    bottomBorder: b,
  );
}

CellStyle _dateStyle({bool zebra = false}) {
  final b = _thin();
  return CellStyle(
    numberFormat: NumFormat.custom(formatCode: 'DD MMM YYYY'),
    indent: 1,
    backgroundColorHex: zebra ? ExcelColor.teal50 : ExcelColor.white,
    leftBorder: b,
    rightBorder: b,
    topBorder: b,
    bottomBorder: b,
  );
}

CellStyle _numStyle(bool decimal, {bool zebra = false}) {
  final b = _thin();
  return CellStyle(
    numberFormat: decimal ? NumFormat.standard_4 : NumFormat.standard_3,
    indent: 1,
    backgroundColorHex: zebra ? ExcelColor.teal50 : ExcelColor.white,
    leftBorder: b,
    rightBorder: b,
    topBorder: b,
    bottomBorder: b,
  );
}

CellStyle _totalStyle() {
  final t = _thin();
  final m = _medium();
  return CellStyle(
    bold: true,
    indent: 1,
    leftBorder: t,
    rightBorder: t,
    topBorder: m,
    bottomBorder: t,
  );
}

CellIndex _at(int col, int row) =>
    CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row);

/// Rakit workbook template dari item terfilter.
/// [metaLine] cth 'Oktober 2026 · diekspor 11 Okt 2026' (dirakit pemanggil
/// via strings agar ikut bahasa app). Null → string kosong.
/// Kembalikan bytes siap tulis.
List<int>? buildReportXlsx(
  List<SaasTransaction> items,
  Map<String, String> walletNames, {
  String metaLine = '',
}) {
  final excel = Excel.createExcel();
  excel.rename(excel.getDefaultSheet() ?? 'Sheet1', xlsxSheetName);
  final sheet = excel[xlsxSheetName];
  // Judul + periode.
  sheet.merge(
    CellIndex.indexByString('A1'),
    CellIndex.indexByString('H1'),
  );
  sheet.updateCell(
    CellIndex.indexByString('A1'),
    TextCellValue(xlsxTitle),
    cellStyle: _titleStyle(),
  );
  sheet.merge(
    CellIndex.indexByString('A2'),
    CellIndex.indexByString('H2'),
  );
  final meta = metaLine;
  sheet.updateCell(
    CellIndex.indexByString('A2'),
    TextCellValue(meta),
    cellStyle: _textStyle(),
  );
  sheet.setRowHeight(0, 28);
  sheet.setRowHeight(2, 8);
  // Header baris 4 (indeks 3).
  final hs = _headerStyle();
  for (var c = 0; c < xlsxHeader.length; c++) {
    sheet.updateCell(_at(c, 3), TextCellValue(xlsxHeader[c]), cellStyle: hs);
  }
  sheet.setRowHeight(3, 22);
  // Data dari baris 5 (indeks 4).
  final colText = List.generate(
    xlsxHeader.length,
    (c) => <String>[xlsxHeader[c]],
  );
  var totalOut = 0.0;
  var r = 4;
  for (var i = 0; i < items.length; i++) {
    final t = items[i];
    final zebra = i.isEven;
    final rawDate = t.date ?? '';
    final dt = rawDate.length >= 10
        ? DateTime.tryParse(rawDate.substring(0, 10))
        : null;
    final dec = t.amount % 1 != 0;
    final dompet = walletNames[t.walletId] ?? '';
    final isTransfer = t.type == 'transfer';
    // Dari selalu = dompet sumber (bisa difilter per dompet);
    // Ke hanya terisi untuk transfer.
    final dari = dompet;
    final ke = isTransfer ? (walletNames[t.toWalletId] ?? '') : '';
    final kategori = t.category ?? '';
    final catatan = t.note ?? '';
    if (t.type == 'out') totalOut += t.amount;
    sheet.updateCell(
      _at(0, r),
      dt == null ? TextCellValue('') : DateCellValue.fromDateTime(dt),
      cellStyle: _dateStyle(zebra: zebra),
    );
    sheet.updateCell(
      _at(1, r),
      TextCellValue(t.type),
      cellStyle: _textStyle(zebra: zebra),
    );
    sheet.updateCell(
      _at(2, r),
      dec ? DoubleCellValue(t.amount) : IntCellValue(t.amount.toInt()),
      cellStyle: _numStyle(dec, zebra: zebra),
    );
    sheet.updateCell(
      _at(3, r),
      TextCellValue(dompet),
      cellStyle: _textStyle(zebra: zebra),
    );
    sheet.updateCell(
      _at(4, r),
      TextCellValue(dari),
      cellStyle: _textStyle(zebra: zebra),
    );
    sheet.updateCell(
      _at(5, r),
      TextCellValue(ke),
      cellStyle: _textStyle(zebra: zebra),
    );
    sheet.updateCell(
      _at(6, r),
      TextCellValue(kategori),
      cellStyle: _textStyle(zebra: zebra),
    );
    sheet.updateCell(
      _at(7, r),
      TextCellValue(catatan),
      cellStyle: _noteStyle(zebra: zebra),
    );
    colText[0].add(rawDate);
    colText[1].add(t.type);
    colText[2].add(t.amount.toStringAsFixed(dec ? 2 : 0));
    colText[3].add(dompet);
    colText[4].add(dari);
    colText[5].add(ke);
    colText[6].add(kategori);
    colText[7].add(catatan);
    r++;
  }
  // Baris TOTAL KELUAR + border tebal atas.
  final ts = _totalStyle();
  final decTotal = totalOut % 1 != 0;
  final totalCells = <CellValue?>[
    TextCellValue('TOTAL KELUAR'),
    TextCellValue(''),
    decTotal
        ? DoubleCellValue(totalOut)
        : IntCellValue(totalOut.toInt()),
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue(''),
    TextCellValue(''),
  ];
  for (var c = 0; c < totalCells.length; c++) {
    sheet.updateCell(_at(c, r), totalCells[c], cellStyle: ts);
  }
  for (var c = 0; c < xlsxHeader.length; c++) {
    sheet.setColumnWidth(c, xlsxFitWidth(colText[c], min: _minWidths[c]));
  }
  sheet.setAutoFilter(
    CellIndex.indexByString('A4'),
    CellIndex.indexByString('H${items.isEmpty ? 4 : 4 + items.length}'),
  );
  sheet.freezePanes(rows: 4);
  return excel.save();
}
