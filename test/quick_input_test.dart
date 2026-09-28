import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/quick_input_parse.dart';

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
const _walls = ['Kas', 'DANA', 'BCA'];

void main() {
  test('nominal satuan ID + jenis default keluar', () {
    final r = parseQuickInput(
      'makan siang 35rb',
      categories: _cats,
      wallets: _walls,
    )!;
    expect(r.amount, 35000);
    expect(r.type, 'out');
    expect(r.category, 'Makanan');
    expect(r.walletName, isNull);
    expect(r.note, 'makan siang');
  });

  test('juta + jenis masuk', () {
    final r = parseQuickInput(
      'gaji september 5jt',
      categories: _cats,
      wallets: _walls,
    )!;
    expect(r.amount, 5000000);
    expect(r.type, 'in');
  });

  test('transfer + dompet sumber disebut duluan', () {
    final r = parseQuickInput(
      'transfer 100rb dana ke bca',
      categories: _cats,
      wallets: _walls,
    )!;
    expect(r.amount, 100000);
    expect(r.type, 'transfer');
    expect(r.walletName, 'DANA');
  });

  test('ribuan titik + dompet + alias kategori', () {
    final r = parseQuickInput(
      'bensin 50.000 kas',
      categories: _cats,
      wallets: _walls,
    )!;
    expect(r.amount, 50000);
    expect(r.category, 'Transportasi');
    expect(r.walletName, 'Kas');
  });

  test('desimal koma + top up masuk', () {
    final r = parseQuickInput(
      'top up dana 1,5jt',
      categories: _cats,
      wallets: _walls,
    )!;
    expect(r.amount, 1500000);
    expect(r.type, 'in');
    expect(r.walletName, 'DANA');
  });

  test('terima mengalahkan kata transfer', () {
    final r = parseQuickInput(
      'terima transfer 200rb',
      categories: _cats,
      wallets: _walls,
    )!;
    expect(r.type, 'in');
  });

  test('tanpa nominal atau nol = null', () {
    QuickInput? q(String s) =>
        parseQuickInput(s, categories: _cats, wallets: _walls);
    expect(q('halo apa kabar'), isNull);
    expect(q('makan gratis'), isNull);
    expect(q('nol 0 rupiah'), isNull);
  });

  test('kapital + kategori kustom diutamakan dari alias', () {
    final r = parseQuickInput(
      'Makan Siang 35RB',
      categories: _cats,
      wallets: _walls,
    )!;
    expect(r.amount, 35000);
    final c = parseQuickInput('jajan 10rb', categories: ['Jajan'], wallets: [])!;
    expect(c.category, 'Jajan');
  });
}
