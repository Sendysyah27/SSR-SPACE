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

const _t4 = '''
1:11 S.
Struk Transaksi
PT.INDOMARCO PRISMATAMA
GEDUNG MENARA INDOMARET
BOULEVARD PANTAI INDAH KAPUK
JAKARTA UTARA
Struk Transaksi
NPWP:901.337.994.6-092.000
BATANGSARI
JALAN BATANGSARI, KEL BATANGSARI
KEC SUKASARI KAB SUBANG, 41250
P/C ICED PALM S LATT
kal. U9llol 69
12.09.26-13:58/4.4.2/T5U9-35335/NIA R/03
NO. ORDER POINT COFFEE : CO5
Indomaret
HARGA JUAL : 22,727
- (NORMAL)
1 25000
TOTAL BELANJA :
PJK RST.: DPP= 22,727 PJK= 2,273
NON TUNAI :
CEK POIN/STAMP/LUCKY DI APPS POINKU
P/C ICED FALM S LATT
QR SHOPEEPAY-TRXID :T5U92609121358220103
LAYANAN KONSUMEN
25,000
NO: ***AAAG, PURCHASE:25,000
ID POINKU: XXXX6761
25,000
25,000
Isi Pulsa Gratis Admin!
''';

const _t5 = '''
BANGOR KAFE
Subtotal Rp73.636
Total Rp73.636
Pajak Rp7.364
Grand Total: .0
Gopay: Rp81.000
''';

const _t6 = '''
KOPI KENANGAN
KOPI SUSU 1 38000
KOPI HITAM 1 40000
TOTAL ITEM : 2
TOTAL : 78.000
06/02/35
12.10.26
''';

const _t7 = '''
KOPI KENANGAN
TOTAL
TUNAI
KEMBALI
19,900
25.000
34,000
78,000
100,000
22,000
QR SHOPEEPAY-TRXID :T5U92609121358220103
ID POINKU: XXXX6761
12.10.26
''';

const _t8 = '''
KOPI KENANGAN
TOTAL
TUNAI
KEMBALI
19,900
Kopi Kenangan Mantan 1 25000
Matcha Latte 1 34000
Friend Chip Cookie 1 19900
Server KK1
ML-F1
Order Date: 48
ORDER #A 2
KEC SUKASARI KAB SUBANG, 41250
NPWP:901.337.994.6-092.000
25.000
34,000
78,000
100,000
22,000
12.10.26
''';

const _t9 = '''
KOPI KENANGAN
TOTAL
TUNAI
KEMBALI
19,900
Kopi Kenangan Mantan 1 25000
Matcha Latte 1 34000
Friend Chip Cookie 1 19900
ihatsApp + 7818
WhatsApp 081234567890
Order Date: 48
25.000
34,000
78,000
100,000
22,000
12.10.26
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

  test('OCR acak: total kecopot, PURCHASE + angka nyasar', () {
    final r = parseReceipt(_t4);
    expect(r.amount, 25000);
    expect(r.confident, isTrue);
    expect(r.merchant, 'INDOMARET');
    expect(r.date?.day, 12);
  });

  test('PURCHASE jadi total bila baris total kosong', () {
    const raw = 'TOKO X\nNO:AA,PURCHASE:25,000';
    expect(parseReceipt(raw).amount, 25000);
  });

  test('modus angka nyasar butuh suara 2+', () {
    const raw = 'INDOMARET\nTOTAL :\nLAYANAN KONSUMEN\n25,000\n25,000';
    expect(parseReceipt(raw).amount, 25000);
  });

  test('angka nyasar seri = tolak, bukan comot', () {
    const raw = 'INDOMARET\nTOTAL :\n50.000\n8.750';
    final r = parseReceipt(raw);
    expect(r.amount, isNull);
    expect(r.confident, isFalse);
  });

  test('grand mangled -> nominal pembayaran', () {
    final r = parseReceipt(_t5);
    expect(r.amount, 81000);
    expect(r.confident, isTrue);
  });

  test('grand valid menang atas total', () {
    const raw = 'TOTAL : 73.636\nGRAND TOTAL : 81.000';
    expect(parseReceipt(raw).amount, 81000);
  });

  test('tunai lebih + kembali bukan belanja', () {
    const raw = 'TOTAL : 41.250\nGRAND TOTAL :\nTUNAI : 50.000\nKEMBALI : 8.750';
    expect(parseReceipt(raw).amount, 41250);
  });

  test('kopi: cacah dan tanggal masa depan ditolak', () {
    final r = parseReceipt(_t6);
    expect(r.amount, 78000);
    expect(r.date?.day, 12);
    expect(r.date?.month, 10);
  });

  test('angka 1 digit tak jadi amount', () {
    final r = parseReceipt('TOTAL : 1');
    expect(r.amount, isNull);
    expect(r.confident, isFalse);
  });

  test('baris cacah item bukan total', () {
    expect(parseReceipt('TOTAL ITEM : 2').amount, isNull);
  });

  test('tanggal masa depan ditolak', () {
    expect(parseReceipt('STRUK\n06/02/35').date, isNull);
  });

  test('relasi tunai-kembali: tengahnya total', () {
    final r = parseReceipt(_t7);
    expect(r.amount, 78000);
    expect(r.confident, isTrue);
    expect(r.date?.day, 12);
    expect(r.date?.month, 10);
  });

  test('triple dasar 100-22=78', () {
    const raw = 'TOTAL\nTUNAI\nKEMBALI\n100.000\n22.000\n78.000';
    expect(parseReceipt(raw).amount, 78000);
  });

  test('multi-triple = tolak', () {
    const raw = 'TOTAL\nTUNAI\nKEMBALI\n'
        '100.000\n60.000\n40.000\n50.000\n30.000\n20.000';
    final r = parseReceipt(raw);
    expect(r.amount, isNull);
    expect(r.confident, isFalse);
  });

  test('jumlah item = total nyasar', () {
    const raw = 'WARUNG\nA 1 38000\nB 1 40000\nTOTAL\n78.000\n15.000';
    expect(parseReceipt(raw).amount, 78000);
  });

  test('item hanya nama produk, sampah dibuang', () {
    final r = parseReceipt(_t8);
    expect(
      r.items,
      [
        'Kopi Kenangan Mantan 25000',
        'Matcha Latte 34000',
        'Friend Chip Cookie 19900',
      ],
    );
    expect(r.amount, 78000);
  });

  test('catatan tanpa fragmen server/order/alamat', () {
    final n = receiptNote(parseReceipt(_t8));
    expect(n.contains('Mantan'), isTrue);
    expect(n.contains('Server'), isFalse);
    expect(n.contains('Order'), isFalse);
    expect(n.contains('41250'), isFalse);
  });

  test('kode NPWP/poinku bukan barang', () {
    const raw = 'TOKO X\nNPWP: 12345678\nID POINKU: XXXX6761\nSABUN 1 5000 5,000';
    final r = parseReceipt(raw);
    expect(r.items.any((i) => i.contains('NPWP')), isFalse);
    expect(r.items.any((i) => i.contains('POINKU')), isFalse);
    expect(r.items, ['SABUN 5000']);
  });

  test('catatan hanya produk, tanpa nomor/kontak', () {
    final r = parseReceipt(_t9);
    expect(r.merchant, 'KOPI KENANGAN');
    expect(
      r.items,
      [
        'Kopi Kenangan Mantan 25000',
        'Matcha Latte 34000',
        'Friend Chip Cookie 19900',
      ],
    );
    expect(
      receiptNote(r),
      'KOPI KENANGAN · Kopi Kenangan Mantan 25000, '
      'Matcha Latte 34000, Friend Chip Cookie 19900',
    );
    expect(r.amount, 78000);
  });

  test('merchant menolak baris angka murni', () {
    expect(parseReceipt('19,900\nTOKO KOPI').merchant, 'TOKO KOPI');
  });

  test('baris kontak + dibuang', () {
    const raw = 'ihatsApp + 7818\nTOTAL : 25,000';
    expect(parseReceipt(raw).items, isEmpty);
  });

  test('baris terfragmentasi digabung', () {
    const raw = 'Kopi Kenangan Mantan\n1 25000\nTOTAL : 25,000';
    expect(
      parseReceipt(raw).items,
      ['Kopi Kenangan Mantan 25000'],
    );
  });

  test('caps-rusak ciri OCR dibuang', () {
    const raw = 'ihatsApp 7818\nTOTAL : 25,000';
    expect(parseReceipt(raw).items, isEmpty);
  });

  test('split item nama + nominal', () {
    final a = splitReceiptItem('Kopi Kenangan Mantan 25000');
    expect(a.name, 'Kopi Kenangan Mantan');
    expect(a.amount, 25000);
    final b = splitReceiptItem('Roti 14900.0');
    expect(b.name, 'Roti');
    expect(b.amount, 14900);
    final c = splitReceiptItem('TanpaNominal');
    expect(c.name, 'TanpaNominal');
    expect(c.amount, 0);
  });

  test('footer di bawah total bukan item (Kopi Kenangan)', () {
    const raw = 'KOPI KENANGAN\n'
        'Kopi Kenangan Mantan 19000\n'
        'Matcha Latte 25000\n'
        'Friend Chip Cookie 2 34000\n'
        'TOTAL 78000\n'
        'PT BURL BERKAH BOGA 19900\n'
        'DKI JAKARTA 25000\n'
        'NPWP 01.234.567.8-901.000\n'
        'TERIMA KASIH';
    final r = parseReceipt(raw);
    expect(r.amount, 78000);
    expect(r.merchant, 'KOPI KENANGAN');
    expect(r.items, [
      'Kopi Kenangan Mantan 19000',
      'Matcha Latte 25000',
      'Friend Chip Cookie 34000',
    ]);
  });

  test('tanpa baris total: perilaku lama (fallback)', () {
    const raw = 'TOKO KOPI\nKopi 25000';
    final r = parseReceipt(raw);
    expect(r.items, ['Kopi 25000']);
  });

  test('TOTAL telanjang bukan batas; TOTAL: + angka ya', () {
    const raw = 'TOKO\nKopi 25000\nTOTAL :\n41.250\nPT X 99900';
    final r = parseReceipt(raw);
    expect(r.amount, 41250);
    expect(r.items, ['Kopi 25000']);
  });

  test('mirror: urutan asli header-item-total', () {
    const raw = 'KOPI KENANGAN\n'
        'Jl. Merdeka No. 45, Bandung\n'
        'Telp 022-1234567\n'
        'No : TRX-2026-00891\n'
        'Kasir : Sinta\n'
        '12/10/2026 14:35\n'
        'Kopi Mantan 19000\n'
        'Matcha Latte 2 50000\n'
        'TOTAL : 69000\n'
        'QRIS : 69000\n'
        'TERIMA KASIH';
    final m = mirrorReceipt(raw).map((e) => e.text).toList();
    expect(
      m,
      [
        'KOPI KENANGAN',
        'Jl. Merdeka No. 45, Bandung',
        'Telp 022-1234567',
        'No : TRX-2026-00891',
        'Kasir : Sinta',
        '12/10/2026 14:35',
        'Kopi Mantan',
        'Matcha Latte x2',
        'TOTAL :',
        'QRIS :',
        'TERIMA KASIH',
      ],
    );
    final rows = mirrorReceipt(raw);
    expect(rows[0].centered, isTrue);
    expect(rows[0].bold, isTrue);
    expect(rows[6].amount, 19000);
    expect(rows[8].amount, 69000);
    expect(rows[8].bold, isTrue);
  });

  test('mirror: footer sampah dibuang, item utuh', () {
    const raw = 'INDOMARET\n'
        'Kopi 25000\n'
        'TOTAL : 25000\n'
        'PT INDOMARCO PRISMATAMA\n'
        'NPWP 01.234.567.8-901.000\n'
        'TERIMA KASIH';
    final m = mirrorReceipt(raw).map((e) => e.text).toList();
    expect(m, ['INDOMARET', 'Kopi', 'TOTAL :', 'TERIMA KASIH']);
  });

  test('bukti indomaret: total belanja bare + tender sesudah', () {
    const raw = 'INDOMARET\n'
        'AMANDA BROWNIES ORI\n'
        'OREO ORIGINAL 140G\n'
        '57500\n'
        'TOTAL BELANJA\n'
        '157,700\n'
        'TUNAI 200.000\n'
        'KEMBALI 42.300';
    final r = parseReceipt(raw);
    expect(r.amount, 157700);
    expect(r.confident, isTrue);
  });

  test('voucher tak pernah menang atas total', () {
    const raw = 'TOKO\nVOUCHER 5900\nTOTAL BELANJA\n45700\nTUNAI 50000';
    expect(parseReceipt(raw).amount, 45700);
  });

  test('mirror: harga yatim dipasangkan nama di atasnya', () {
    const raw = 'TOKO\nAMANDA BROWNIES ORI\n57500\nTOTAL 57500';
    final m = mirrorReceipt(raw);
    expect(m[1].text, 'AMANDA BROWNIES ORI');
    expect(m[1].amount, 57500);
  });

  test('mirror: pairOrphans mati untuk BBM', () {
    const raw = 'Toko\nkopi susu\nTERIMA KASIH\n25000\nTOTAL 25000';
    final on = mirrorReceipt(raw);
    expect(on.any((e) => e.text == 'Toko' && e.amount == 25000), isTrue);
    final off = mirrorReceipt(raw, pairOrphans: false);
    expect(off.any((e) => e.text == 'Toko' && e.amount == 25000), isFalse);
  });

  test('kenangan: varian gabung ke produk induk', () {
    const raw = 'KOPI KENANGAN\nKOPI KENANGAN MANTAN\nNormal Ice\n25000\n'
        'MATCHA LATTE\nBlend Less Sugar\n34000\nTOTAL 59000';
    final r = parseReceipt(raw);
    expect(r.items, [
      'KOPI KENANGAN MANTAN Normal Ice 25000',
      'MATCHA LATTE Blend Less Sugar 34000',
    ]);
    expect(r.amount, 59000);
  });

  test('bangor: sub-item pilihan kepisah', () {
    const raw = 'BURGER BANGOR\nBurgetang 4 45000\nPilihan Nugget\n12000\n'
        'TOTAL 57000';
    final r = parseReceipt(raw);
    expect(r.items, ['Burgetang 45000', 'Pilihan Nugget 12000']);
    expect(r.amount, 57000);
  });

  test('struk detail: alamat kasir telp nostruk jam bayar', () {
    const raw = 'KOPI KENANGAN\n'
        'Jl. Merdeka No. 45, Bandung\n'
        'Telp 022-1234567\n'
        'No : TRX-2026-00891\n'
        'Kasir : Sinta\n'
        '12/10/2026 14:35\n'
        'Kopi Mantan 19000\n'
        'Matcha Latte 2 50000\n'
        'TOTAL : 69000\n'
        'QRIS : 69000\n'
        'TERIMA KASIH';
    final r = parseReceipt(raw);
    expect(r.merchant, 'KOPI KENANGAN');
    expect(r.address, contains('Merdeka'));
    expect(r.cashier, 'Sinta');
    expect(r.phone, contains('022'));
    expect(r.receiptNo, contains('00891'));
    expect(r.time, '14:35');
    expect(r.payType, 'QRIS');
    expect(r.amount, 69000);
  });

  test('struk rusak: field detail semua null', () {
    const raw = 'Kopi 25000\nTOTAL 25000';
    final r = parseReceipt(raw);
    expect(r.address, isNull);
    expect(r.cashier, isNull);
    expect(r.phone, isNull);
    expect(r.receiptNo, isNull);
    expect(r.time, isNull);
  });

  test('lineItems terstruktur nama qty harga', () {
    const raw = 'TOKO\nMatcha Latte 2 50000\nKopi 25000\nTOTAL 75000';
    final r = parseReceipt(raw);
    expect(r.lineItems.length, 2);
    expect(r.lineItems[0].name, 'Matcha Latte');
    expect(r.lineItems[0].qty, 2);
    expect(r.lineItems[0].price, 50000);
    expect(r.lineItems[1].qty, 1);
  });
}
