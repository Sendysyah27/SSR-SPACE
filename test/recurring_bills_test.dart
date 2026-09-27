import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/recurring_bills.dart';

RecurringBill _bill({
  String period = 'monthly',
  int anchorDay = 5,
  String nextDue = '2026-09-05',
  bool active = true,
  String walletId = 'w1',
  double amount = 50000,
}) =>
    RecurringBill(
      id: 'b1',
      label: 'Kos',
      amount: amount,
      category: 'Tagihan',
      walletId: walletId,
      period: period,
      anchorDay: anchorDay,
      nextDue: nextDue,
      active: active,
    );

void main() {
  test('bulanan: jatuh tempo dari jangkar', () {
    expect(monthlyDue(2026, 9, 5), DateTime(2026, 9, 5));
    expect(advanceBill(_bill(), DateTime(2026, 9, 5)), DateTime(2026, 10, 5));
    expect(advanceBill(_bill(), DateTime(2026, 12, 5)), DateTime(2027, 1, 5));
  });

  test('mingguan: +7 hari', () {
    final b = _bill(period: 'weekly', nextDue: '2026-09-21');
    expect(advanceBill(b, DateTime(2026, 9, 21)), DateTime(2026, 9, 28));
  });

  test('jepit akhir bulan: kabisat dan non-kabisat', () {
    expect(monthlyDue(2026, 2, 30), DateTime(2026, 2, 28));
    expect(monthlyDue(2024, 2, 30), DateTime(2024, 2, 29));
    expect(monthlyDue(2026, 4, 31), DateTime(2026, 4, 30));
    expect(
      advanceBill(_bill(anchorDay: 31), DateTime(2026, 1, 31)),
      DateTime(2026, 2, 28),
    );
  });

  test('jatuh tempo: lewat dan hari ini true, besok false', () {
    final now = DateTime(2026, 9, 27);
    expect(isBillDue(_bill(nextDue: '2026-09-20'), now), true);
    expect(isBillDue(_bill(nextDue: '2026-09-27'), now), true);
    expect(isBillDue(_bill(nextDue: '2026-09-28'), now), false);
    expect(isBillDue(_bill(nextDue: '2026-09-20', active: false), now), false);
  });

  test('dompet hilang menonaktifkan item', () {
    final out = markWalletGone(
      [_bill(walletId: 'w1'), _bill(walletId: 'w9')],
      {'w1'},
    );
    expect(out[0].active, true);
    expect(out[1].active, false);
  });

  test('parse toleran: rusak dibuang, cap 30', () {    expect(RecurringBill.tryParse({'a': 1}), isNull);
    expect(RecurringBill.tryParse(_bill(amount: -5).toJson()), isNull);
    expect(
      RecurringBill.tryParse(_bill(period: 'yearly').toJson()),
      isNull,
    );
    final many = List.generate(
      40,
      (i) => _bill().copyWith(nextDue: '2026-09-05'),
    );
    expect(many.take(maxBills).length, 30);
  });

  test('catat memajukan nextDue dan merekam entri', () {
    final rec = recordPayment(
      _bill(nextDue: '2026-09-05'),
      '2026-09-05',
      50000,
      DateTime(2026, 9, 27, 10, 0),
    );
    expect(rec.bill.nextDue, '2026-10-05');
    expect(rec.entry.billId, 'b1');
    expect(rec.entry.date, '2026-09-05');
    expect(rec.entry.amount, 50000);
  });

  test('lewati tanpa insert tak merekam entri', () {
    final b = _bill(nextDue: '2026-09-21', period: 'weekly');
    expect(advanceBill(b, DateTime(2026, 9, 21)), DateTime(2026, 9, 28));
  });

  test('riwayat terbaru dulu, rusak dibuang', () {
    final all = [
      const PaymentEntry(
        billId: 'b1',
        date: '2026-08-05',
        amount: 50000,
        paidAt: '2026-08-05T10:00:00',
      ),
      const PaymentEntry(
        billId: 'b1',
        date: '2026-09-05',
        amount: 50000,
        paidAt: '2026-09-05T10:00:00',
      ),
      const PaymentEntry(
        billId: 'b9',
        date: '2026-09-05',
        amount: 1000,
        paidAt: '2026-09-05T10:00:00',
      ),
    ];
    final rows = historyFor(all, 'b1');
    expect(rows.length, 2);
    expect(rows.first.date, '2026-09-05');
    expect(PaymentEntry.tryParse({'a': 1}), isNull);
    expect(
      PaymentEntry.tryParse(
        const PaymentEntry(
          billId: 'b1',
          date: '2026-09-05',
          amount: -5,
          paidAt: 'x',
        ).toJson(),
      ),
      isNull,
    );
  });
}
