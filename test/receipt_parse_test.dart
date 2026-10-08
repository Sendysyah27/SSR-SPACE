import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/receipt_parse.dart';

const _t1 = '''
PT INDOMARCO PRISMATAMA
ARIF RAHMAN HAKIM
1.08.26-21:37/4.4.2/T1HX-49330/JAMAL/01
LUR AYAM NEGRI WHL 5000 25.5 127,500
IMAX ICY BKS 20'S 1 31000 31,000
FTEX PL D.SRH 30'S 1 16000 16,000
VOUCHER : (2,200)
TOTAL BELANJA : 172,300
NON TUNAI : 172,300
ANDA HEMAT : 2,200
HARGA JUAL : 172,914
SHOPEEPAY-TRXID:T1HX2608112137350101
PURCHASE:172,300
''';

const _t2 = '''
5.08.26-14:19/4.4.2/T1HX-49372/SENDY/01
ANIA MNYK GR PCH 2L 12 42600 511,200
VOUCHER : (3,600)
TOTAL BELANJA : 507,600
NON TUNAI : 507,600
HARGA JUAL : 460,541
Payment Point Indomaret
Rp 507,600
Ambil : 15.08.2620:00-20:59
''';

const _t3 = '''
PT.INDOMARCO PRISMATAMA
BATANGSARI JALAN BATANGSARI, KEL BATANGSARI KEC SUKASARI KAB SUBANG, 41250
12.09.26-13:58/4.4.2/T5U9-35335/NIA R/03
P/C ICED PALM S LATT 1 25000 25,000
TOTAL BELANJA : 25,000
NON TUNAI : 25,000
PJK RST.: DPP= 22,727 PJK= 2,273
HARGA JUAL : 22,727
NO:***AAAG,PURCHASE:25,000
''';

void main() {
  test('total koma-ribuan dari TOTAL BELANJA', () {
    final r = parseReceipt(_t1);
    expect(r.amount, 172300);
    expect(r.confident, isTrue);
  });

  test('tolak KEMBALI dan HARGA JUAL sebagai total', () {
    const raw = 'TUNAI : 200,000\nKEMBALI : 27,700\n'
        'TOTAL BELANJA : 172,300\nHARGA JUAL : 172,914';
    expect(parseReceipt(raw).amount, 172300);
  });

  test('tanggal terpotong tetap kebaca', () {
    final r = parseReceipt(_t1);
    expect(r.date?.day, 1);
    expect(r.date?.month, 8);
    expect(r.date?.year, 2026);
  });

  test('tanggal ambil match terakhir', () {
    // Jujur OCR: "15.08.26" terpotong jadi "5.08.26" + "15.08.2620:00"
    // (nempel jam, tahun 2620 ditolak) → terbaca 5, user koreksi di preview.
    final r = parseReceipt(_t2);
    expect(r.date?.day, 5);
  });

  test('merchant Indomaret dari keyword', () {
    expect(parseReceipt(_t1).merchant, 'INDOMARET');
    expect(parseReceipt(_t2).merchant, 'INDOMARET');
  });

  test('item 4 kolom dan 3 kolom', () {
    final r = parseReceipt(_t1);
    expect(r.items.length, 3);
    expect(r.items.first.contains('127'), isTrue);
  });

  test('voucher bukan item', () {
    final r = parseReceipt(_t1);
    expect(r.voucher, 2200);
    expect(r.items.any((i) => i.contains('VOUCHER')), isFalse);
  });

  test('tanpa total = tak confident', () {
    const raw = 'TOKO KELONTONG\nSABUN 1 5000 5,000';
    final r = parseReceipt(raw);
    expect(r.amount, isNull);
    expect(r.confident, isFalse);
  });

  test('note dibatasi 200 char', () {
    final r = parseReceipt(_t2);
    expect(receiptNote(r).length, lessThanOrEqualTo(200));
    expect(receiptNote(r).contains('507'), isFalse);
  });

  test('teks kosong aman', () {
    final r = parseReceipt('   \n  ');
    expect(r.confident, isFalse);
    expect(r.items, isEmpty);
  });

  test('struk nyata: total 25rb, jebakan tak kepilih', () {
    final r = parseReceipt(_t3);
    expect(r.amount, 25000);
    expect(r.confident, isTrue);
    expect(r.merchant, 'INDOMARET');
    expect(r.date?.day, 12);
    expect(r.date?.month, 9);
  });

  test('OCR T0TAL tetap kebaca', () {
    const raw = 'INDOMARET\nT0TAL BELANJA : 41.250\nTUNAI : 50.000';
    expect(parseReceipt(raw).amount, 41250);
  });

  test('OCR TOTA L spasi tetap kebaca', () {
    const raw = 'INDOMARET\nTOTA L : 41.250\nTUNAI : 50.000';
    expect(parseReceipt(raw).amount, 41250);
  });

  test('total dan angka beda baris', () {
    const raw = 'INDOMARET\nTOTAL :\n41.250\nTUNAI : 50.000';
    expect(parseReceipt(raw).amount, 41250);
  });

  test('baris gabung TOTAL+TUNAI ambil total', () {
    const raw = 'INDOMARET\nTOTAL 41.250 TUNAI 50.000\nKEMBALI 8.750';
    expect(parseReceipt(raw).amount, 41250);
  });

  test('postcode alamat bukan total', () {
    const raw = 'INDOMARET\nKEC SUKASARI KAB SUBANG 41250';
    final r = parseReceipt(raw);
    expect(r.amount, isNull);
    expect(r.confident, isFalse);
  });
}
