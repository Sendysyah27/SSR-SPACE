import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/saving.dart';

SaasTransaction tx({
  required String type,
  required double amount,
  String? category,
  String? date,
}) {
  return SaasTransaction(
    id: 'x',
    orgId: 'o',
    type: type,
    amount: amount,
    category: category,
    date: date,
  );
}

void main() {
  test('isSavingCategory cocok ID/EN case-insensitive', () {
    expect(isSavingCategory('Tabungan'), isTrue);
    expect(isSavingCategory('tabungan darurat'), isTrue);
    expect(isSavingCategory('Saving'), isTrue);
    expect(isSavingCategory('SAVINGS'), isTrue);
  });

  test('isSavingCategory menolak non-tabungan', () {
    expect(isSavingCategory('Makan'), isFalse);
    expect(isSavingCategory('Belanja'), isFalse);
    expect(isSavingCategory(''), isFalse);
    expect(isSavingCategory(null), isFalse);
  });

  test('savingOutOf hanya out tabungan (in/transfer dikecualikan)', () {
    final txs = [
      tx(type: 'out', amount: 50000, category: 'Tabungan', date: '2026-09-05'),
      tx(type: 'out', amount: 25000, category: 'Tabungan', date: '2026-08-05'),
      tx(type: 'out', amount: 10000, category: 'Makan', date: '2026-09-05'),
      tx(type: 'in', amount: 70000, category: 'Tabungan', date: '2026-09-05'),
      tx(
          type: 'transfer',
          amount: 9000,
          category: 'Tabungan',
          date: '2026-09-05'),
    ];
    expect(savingOutOf(txs, month: '2026-09'), 50000);
    expect(savingOutOf(txs), 75000);
    expect(savingOutOf(txs, month: '2026-07'), 0);
  });

  test('inOfMonth menjumlah in sebulan', () {
    final txs = [
      tx(type: 'in', amount: 1000000, date: '2026-09-01'),
      tx(type: 'in', amount: 70000, category: 'Tabungan', date: '2026-09-05'),
      tx(type: 'in', amount: 500000, date: '2026-08-01'),
      tx(type: 'out', amount: 10000, category: 'Makan', date: '2026-09-05'),
    ];
    expect(inOfMonth(txs, '2026-09'), 1070000);
    expect(inOfMonth(txs, '2026-07'), 0);
  });
}
