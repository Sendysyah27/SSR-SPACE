import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/csv_import_logic.dart';

// Iris 2a: parser CSV import murni (dipakai Task 6 untuk UI import).
// Logika di csv_import_logic.dart bebas flutter sehingga juga
// terverifikasi lokal via `dart` (lihat task-5-report.md).

void main() {
  test('detectDelimiter koma vs titik-koma', () {
    expect(detectDelimiter('tanggal,nominal,jenis\n'), ',');
    expect(detectDelimiter('tanggal;nominal;jenis\n'), ';');
  });

  test('detectDelimiter tab terbanyak menang', () {
    expect(detectDelimiter('tanggal\tnominal\tjenis\n'), '\t');
  });

  test('parseAmountValue format ID Rp1.234,50', () {
    expect(parseAmountValue('Rp1.234,50'), 1234.5);
  });

  test('parseAmountValue format EN 1,234.50', () {
    expect(parseAmountValue('1,234.50'), 1234.5);
  });

  test('parseAmountValue titik saja tanpa 2 digit akhir = ribuan', () {
    expect(parseAmountValue('1.234.567'), 1234567);
  });

  test('parseAmountValue polos dan IDR berspasi', () {
    expect(parseAmountValue('25000'), 25000);
    expect(parseAmountValue('IDR 25.000'), 25000);
  });

  test('parseAmountValue sampah/nol/negatif throw FormatException', () {
    expect(() => parseAmountValue('abc'), throwsFormatException);
    expect(() => parseAmountValue(''), throwsFormatException);
    expect(() => parseAmountValue('0'), throwsFormatException);
    expect(() => parseAmountValue('-5000'), throwsFormatException);
  });

  test('parseDateValue dd/MM/yyyy dan ISO passthrough', () {
    expect(parseDateValue('26/09/2026'), '2026-09-26');
    expect(parseDateValue('2026-09-26'), '2026-09-26');
  });

  test('parseDateValue dd-MM-yyyy dan yyyyMMdd', () {
    expect(parseDateValue('26-09-2026'), '2026-09-26');
    expect(parseDateValue('20260926'), '2026-09-26');
  });

  test('parseDateValue tak dikenal / bulan invalid throw', () {
    expect(() => parseDateValue('26 Sep 2026'), throwsFormatException);
    expect(() => parseDateValue('2026-13-01'), throwsFormatException);
  });

  test('parseTypeValue masuk/keluar/transfer', () {
    expect(parseTypeValue('masuk'), 'in');
    expect(parseTypeValue('Keluar'), 'out');
    expect(parseTypeValue('TF'), 'transfer');
  });

  test('parseTypeValue alias EN + ID', () {
    expect(parseTypeValue('income'), 'in');
    expect(parseTypeValue('pemasukan'), 'in');
    expect(parseTypeValue('belanja'), 'out');
    expect(parseTypeValue('mutasi'), 'transfer');
  });

  test('parseTypeValue asing throw FormatException', () {
    expect(() => parseTypeValue('ngutang'), throwsFormatException);
  });

  test('neutralizeFormula prefix apostrof, teks biasa utuh', () {
    expect(neutralizeFormula('=CMD()'), "'=CMD()");
    expect(neutralizeFormula('  +62812'), "'+62812");
    expect(neutralizeFormula('Beras'), 'Beras');
  });

  test('preview campuran: valid + kosong skip + nominal rusak error', () {
    const csv =
        'tanggal,nominal,jenis,dompet,kategori,catatan\n'
        '26/09/2026,"Rp1.234,50",masuk,DANA,Gaji,ok\n'
        ',, ,,,\n'
        '26/09/2026,abc,keluar,DANA,Belanja,rusak\n';
    final p = parseCsvPreview(csv);
    expect(p.rows.length, 1);
    expect(p.errors.length, 1);
    expect(p.rows.first.date, '2026-09-26');
    expect(p.rows.first.amount, 1234.5);
    expect(p.rows.first.type, 'in');
    expect(p.errors.first.lineNo, 4);
  });

  test('preview header kurang kolom wajib jadi error lineNo 0', () {
    final p = parseCsvPreview('tanggal,dompet\n2026-09-26,DANA\n');
    expect(p.rows, isEmpty);
    expect(p.errors.length, 1);
    expect(p.errors.first.lineNo, 0);
    expect(p.errors.first.message, contains('header kurang'));
  });

  test('preview nominal formula jadi error baris', () {
    const csv = 'tanggal,nominal,jenis\n26/09/2026,=CMD(),masuk\n';
    final p = parseCsvPreview(csv);
    expect(p.rows, isEmpty);
    expect(p.errors.length, 1);
    expect(p.errors.first.lineNo, 2);
  });

  test('preview tanggal rusak dan jenis asing jadi error per baris', () {
    const csv =
        'tanggal,nominal,jenis\n'
        '26 Sep 2026,10000,masuk\n'
        '26/09/2026,10000,ngutang\n';
    final p = parseCsvPreview(csv);
    expect(p.rows, isEmpty);
    expect(p.errors.length, 2);
  });

  test('preview sel teks formula dinetralkan, bukan error', () {
    const csv =
        'tanggal,nominal,jenis,catatan\n26/09/2026,10000,masuk,=HYPERLINK()\n';
    final p = parseCsvPreview(csv);
    expect(p.errors, isEmpty);
    expect(p.rows.first.note, "'=HYPERLINK()");
  });

  test('preview titik-koma + header EN + kolom ke_dompet', () {
    const csv =
        'date;amount;type;wallet;to_wallet\n'
        '2026-09-26;10000;transfer;DANA;BCA\n';
    final p = parseCsvPreview(csv);
    expect(p.errors, isEmpty);
    expect(p.rows.first.toWalletName, 'BCA');
    expect(p.rows.first.type, 'transfer');
  });
}
