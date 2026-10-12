import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/debt_track.dart';
import 'package:ssr_space/services/due_reminder.dart';

DateTime d(int day) => DateTime(2026, 10, day);

DebtRecord _debt({
  String id = 'd1',
  double total = 100000,
  String? dueDate = '2026-10-13',
  List<DebtPayment> payments = const [],
}) => DebtRecord(
  id: id,
  kind: 'debt',
  name: 'Budi',
  total: total,
  date: '2026-10-01',
  note: '',
  dueDate: dueDate,
  payments: payments,
);

DueBillInput _bill({
  String id = 'b1',
  String nextDue = '2026-10-13',
  bool active = true,
}) => DueBillInput(id: id, label: 'Listrik', amount: 50000, nextDue: nextDue, active: active);

void main() {
  test('daysUntil presisi hari', () {
    expect(daysUntilDue('2026-10-13', d(10)), 3);
    expect(daysUntilDue('2026-10-10', d(10)), 0);
    expect(daysUntilDue('2026-10-09', d(10)), -1);
    expect(daysUntilDue(null, d(10)), null);
    expect(daysUntilDue('rusak', d(10)), null);
    expect(daysUntilDue('', d(10)), null);
  });

  test('debtDues: lunas & tanpa deadline dikecualikan', () {
    final list = debtDues(
      [
        _debt(),
        _debt(
          id: 'd2',
          total: 50000,
          payments: [const DebtPayment(amount: 50000, date: '2026-10-05')],
        ),
        _debt(id: 'd3', dueDate: null),
      ],
      d(10),
    );
    expect(list.length, 1);
    expect(list.first.record.id, 'd1');
    expect(list.first.daysLeft, 3);
  });

  test('billDues: nonaktif dikecualikan, lewat ikut', () {
    final list = billDues(
      [_bill(), _bill(id: 'b2', active: false), _bill(id: 'b3', nextDue: '2026-10-08')],
      d(10),
    );
    expect(list.length, 2);
    expect(list.map((e) => e.input.id), containsAll(['b1', 'b3']));
  });

  test('notifPlan: H-3 & H-1 masa depan saja', () {
    final plan = notifPlan(
      debts: [_debt()],
      bills: [_bill()],
      today: d(10),
    );
    // Utang due 13: H-3 (10) + H-1 (12). Bill due 13: sama.
    expect(plan.length, 4);
    expect(plan.map((e) => e.date), containsAll(['2026-10-10', '2026-10-12']));
    expect(
      plan.every((e) => e.key.isNotEmpty && e.name.isNotEmpty),
      isTrue,
    );
  });

  test('notifPlan: lewat & hari-H tak dijadwalkan', () {
    final plan = notifPlan(
      debts: [
        _debt(id: 'x1', dueDate: '2026-10-11'),
        _debt(id: 'x2', dueDate: '2026-10-10'),
        _debt(id: 'x3', dueDate: '2026-10-09'),
      ],
      bills: [],
      today: d(10),
    );
    // x1: H-1 (10) saja. x2/x3: tak ada.
    expect(plan.length, 1);
    expect(plan.first.date, '2026-10-10');
  });

  test('dueDate lama absen = null (kompatibel)', () {
    final r = DebtRecord.tryParse({
      'id': 'x',
      'kind': 'debt',
      'name': 'A',
      'total': 1000,
      'date': '2026-10-01',
    })!;
    expect(r.dueDate, null);
    final bad = DebtRecord.tryParse({
      'id': 'x',
      'kind': 'debt',
      'name': 'A',
      'total': 1000,
      'date': '2026-10-01',
      'dueDate': 'rusak',
    })!;
    expect(bad.dueDate, null);
    final full = DebtRecord.tryParse({
      'id': 'x',
      'kind': 'debt',
      'name': 'A',
      'total': 1000,
      'date': '2026-10-01',
      'dueDate': '2026-10-20',
    })!;
    expect(full.dueDate, '2026-10-20');
    expect(DebtRecord.tryParse(full.toJson())!.dueDate, '2026-10-20');
  });
}
