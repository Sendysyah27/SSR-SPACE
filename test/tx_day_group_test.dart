import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/tx_day_group.dart';

SaasTransaction tx(String id, {String? date, String? at}) {
  return SaasTransaction(
    id: id, orgId: 'o', type: 'out', amount: 10000,
    date: date, createdAt: at,
  );
}

void main() {
  test('grup per hari urut DESC, no-date paling bawah', () {
    final out = groupDayBuckets([
      tx('a', date: '2026-09-01', at: '2026-09-01T10:00:00'),
      tx('b', date: '2026-09-02', at: '2026-09-02T10:00:00'),
      tx('c', date: null, at: null),
    ]);
    expect(out.map((b) => b.key), ['2026-09-02', '2026-09-01', 'no-date']);
  });

  test('satu hari berisi in out transfer tetap satu grup', () {
    final items = [
      SaasTransaction(id: 'i', orgId: 'o', type: 'in', amount: 5000, date: '2026-09-05', createdAt: '2026-09-05T09:00:00'),
      SaasTransaction(id: 'o', orgId: 'o', type: 'out', amount: 5000, date: '2026-09-05', createdAt: '2026-09-05T10:00:00'),
      SaasTransaction(id: 't', orgId: 'o', type: 'transfer', amount: 5000, date: '2026-09-05', createdAt: '2026-09-05T11:00:00'),
    ];
    final out = groupDayBuckets(items);
    expect(out.length, 1);
    expect(out.first.items.map((t) => t.id), ['t', 'o', 'i']);
  });

  test('list kosong tanpa grup', () {
    expect(groupDayBuckets([]), isEmpty);
  });

  test('date pendek ikut no-date', () {
    final out = groupDayBuckets([tx('x', date: '2026-09')]);
    expect(out.single.key, 'no-date');
  });

  test('input tidak dimutasi', () {
    final src = [tx('a', date: '2026-09-01'), tx('b', date: '2026-09-02')];
    groupDayBuckets(src);
    expect(src.map((t) => t.id), ['a', 'b']);
  });
}
