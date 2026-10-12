import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/tx_filter.dart';

SaasTransaction tx(
  String id, {
  String type = 'out',
  double amount = 50000,
  String? category,
  String? note,
  String? date,
  String? code,
}) {
  return SaasTransaction(
    id: id,
    orgId: 'o',
    type: type,
    amount: amount,
    category: category,
    note: note,
    date: date,
    code: code,
  );
}

void main() {
  test('query cocok kategori tanpa peduli huruf', () {
    final items = [
      tx('a', category: 'Makan Siang'),
      tx('b', category: 'Belanja'),
    ];
    final out = applyTxFilter(items, const TxFilter(query: 'makan'));
    expect(out.map((t) => t.id), ['a']);
  });

  test('query cocok catatan dan kode', () {
    final items = [
      tx('a', note: 'Bayar ke Warung Bu Tini'),
      tx('b', note: 'Lain', code: 'TX-000041'),
    ];
    expect(
      applyTxFilter(items, const TxFilter(query: 'tini')).map((t) => t.id),
      ['a'],
    );
    expect(
      applyTxFilter(items, const TxFilter(query: 'tx-000041'))
          .map((t) => t.id),
      ['b'],
    );
  });

  test('query kosong = semua lolos', () {
    final items = [tx('a'), tx('b')];
    expect(applyTxFilter(items, const TxFilter()).length, 2);
    expect(applyTxFilter(items, const TxFilter(query: '  ')).length, 2);
  });

  test('filter tipe: hanya yang dipilih', () {
    final items = [
      tx('i', type: 'in'),
      tx('o', type: 'out'),
      tx('t', type: 'transfer'),
    ];
    final out = applyTxFilter(items, const TxFilter(types: {'in', 'out'}));
    expect(out.map((t) => t.id), ['i', 'o']);
  });

  test('filter kategori: cocok persis', () {
    final items = [
      tx('a', category: 'Makan'),
      tx('b', category: 'Belanja'),
      tx('c'),
    ];
    final out = applyTxFilter(items, const TxFilter(cats: {'Makan'}));
    expect(out.map((t) => t.id), ['a']);
  });

  test('rentang tanggal inklusif, tanpa-tanggal gugur bila berbatas', () {
    final items = [
      tx('a', date: '2026-10-01'),
      tx('b', date: '2026-10-15'),
      tx('c', date: '2026-10-31'),
      tx('d'),
    ];
    final out = applyTxFilter(
      items,
      const TxFilter(dateFrom: '2026-10-01', dateTo: '2026-10-15'),
    );
    expect(out.map((t) => t.id), ['a', 'b']);
  });

  test('rentang nominal inklusif dua sisi', () {
    final items = [
      tx('a', amount: 10000),
      tx('b', amount: 50000),
      tx('c', amount: 100000),
    ];
    final out = applyTxFilter(
      items,
      const TxFilter(minAmount: 10000, maxAmount: 50000),
    );
    expect(out.map((t) => t.id), ['a', 'b']);
  });

  test('min lebih besar dari max = tak ada yang lolos', () {
    final items = [tx('a', amount: 50000)];
    expect(
      applyTxFilter(
        items,
        const TxFilter(minAmount: 100000, maxAmount: 10000),
      ),
      isEmpty,
    );
  });

  test('kombinasi query + tipe + nominal menyempit dengan benar', () {
    final items = [
      tx('a', type: 'out', amount: 25000, category: 'Makan', note: 'kopi'),
      tx('b', type: 'out', amount: 25000, category: 'Makan', note: 'nasi'),
      tx('c', type: 'in', amount: 25000, category: 'Makan', note: 'kopi'),
    ];
    final out = applyTxFilter(
      items,
      const TxFilter(query: 'kopi', types: {'out'}, minAmount: 20000),
    );
    expect(out.map((t) => t.id), ['a']);
  });

  test('isEmpty benar untuk kosong vs terisi', () {
    expect(const TxFilter().isEmpty, isTrue);
    expect(const TxFilter(query: 'x').isEmpty, isFalse);
    expect(const TxFilter(types: {'in'}).isEmpty, isFalse);
  });

  test('favorit round-trip utuh', () {
    const fav = TxFav(
      name: 'Kopi',
      filter: TxFilter(query: 'kopi', types: {'out'}),
    );
    final back = TxFav.fromMap(fav.toMap());
    expect(back.name, 'Kopi');
    expect(back.filter.query, 'kopi');
    expect(back.filter.types, {'out'});
  });

  test('tambah favorit potong ekor di cap-10', () {
    var favs = <TxFav>[];
    for (var i = 0; i < 11; i++) {
      favs = addTxFav(favs, TxFav(name: 'f$i', filter: const TxFilter()));
    }
    expect(favs.length, kTxFavCap);
    expect(favs.first.name, 'f10');
    expect(favs.last.name, 'f1');
  });
}
