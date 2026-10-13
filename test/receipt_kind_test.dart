import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/receipt_kind.dart';

const _cats = [
  'Makanan',
  'Transportasi',
  'Belanja',
  'Tagihan',
  'Kesehatan',
  'Pendidikan',
  'Hiburan',
  'Pulsa & Internet',
  'Tabungan',
  'Lainnya',
];

void main() {
  test('minimarket dari keyword merchant', () {
    expect(
      detectReceiptKind('PT.INDOMARCO PRISMATAMA\nTOTAL 25000'),
      ReceiptDocKind.minimarket,
    );
  });

  test('dining dari point coffee', () {
    expect(
      detectReceiptKind('POINT COFFEE\nPURCHASE:25000'),
      ReceiptDocKind.dining,
    );
  });

  test('toko biasa = generic', () {
    expect(
      detectReceiptKind('TOKO KELONTONG\nSABUN 5000'),
      ReceiptDocKind.generic,
    );
  });

  test('merchant indomaret -> Belanja', () {
    expect(
      suggestReceiptCategory(merchant: 'INDOMARET', categories: _cats),
      'Belanja',
    );
  });

  test('merchant point coffee -> Makanan', () {
    expect(
      suggestReceiptCategory(
        merchant: 'POINT COFFEE BATANGSARI',
        categories: _cats,
      ),
      'Makanan',
    );
  });

  test('nama barang kopi -> Makanan', () {
    expect(
      suggestReceiptCategory(
        items: const ['KOPI SUSU 8000'],
        categories: _cats,
      ),
      'Makanan',
    );
  });

  test('tol di TotalProtect bukan Transportasi', () {
    expect(
      suggestReceiptCategory(
        items: const ['Nuvo TotalProtect 304000'],
        categories: _cats,
      ),
      isNot('Transportasi'),
    );
    expect(
      suggestReceiptCategory(
        items: const ['Tol Jagorawi 15000'],
        categories: _cats,
      ),
      'Transportasi',
    );
  });

  test('saran tak ada di daftar = null', () {
    expect(
      suggestReceiptCategory(
        merchant: 'POINT COFFEE',
        categories: const ['Gaji', 'Lainnya'],
      ),
      isNull,
    );
  });

  test('tak dikenal = null', () {
    expect(
      suggestReceiptCategory(
        merchant: 'TOKO X',
        items: const ['BARANG 1000'],
        raw: 'TOKO X',
        categories: _cats,
      ),
      isNull,
    );
  });

  test('layout kind: fuel pharmacy dining minimarket', () {
    expect(detectReceiptKind('SPBU PERTAMINA 34'), ReceiptDocKind.fuel);
    expect(detectReceiptKind('APOTEK K24'), ReceiptDocKind.pharmacy);
    expect(detectReceiptKind('BURGER BANGOR'), ReceiptDocKind.dining);
    expect(detectReceiptKind('ALFAMART'), ReceiptDocKind.minimarket);
    expect(detectReceiptKind('WARUNG BU TINI'), ReceiptDocKind.generic);
  });

  test('profil template per kind', () {
    expect(layoutFor(ReceiptDocKind.fuel).pairOrphans, isFalse);
    expect(layoutFor(ReceiptDocKind.minimarket).priceRight, isTrue);
    expect(layoutFor(ReceiptDocKind.dining).rowTol, 0.5);
  });
}
