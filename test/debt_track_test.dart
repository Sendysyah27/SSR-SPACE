import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/debt_track.dart';

DebtRecord _utang({
  double total = 100000,
  List<DebtPayment> payments = const [],
}) => DebtRecord(
  id: 'd1',
  kind: 'debt',
  name: 'Budi',
  total: total,
  date: '2026-10-01',
  note: 'Pinjam darurat',
  payments: payments,
);

void main() {
  test('awal: sisa = total, belum lunas', () {
    final d = _utang();
    expect(d.paidTotal, 0);
    expect(d.remaining(), 100000);
    expect(d.isSettled, isFalse);
  });

  test('bayar sebagian kurangi sisa + catat riwayat', () {
    final d = _utang().applyPayment(
      const DebtPayment(amount: 30000, date: '2026-10-05'),
    );
    expect(d.paidTotal, 30000);
    expect(d.remaining(), 70000);
    expect(d.payments.length, 1);
    expect(d.isSettled, isFalse);
  });

  test('bayar penuh = lunas', () {
    final d = _utang()
        .applyPayment(const DebtPayment(amount: 40000, date: '2026-10-05'))
        .applyPayment(const DebtPayment(amount: 60000, date: '2026-10-06'));
    expect(d.remaining(), 0);
    expect(d.isSettled, isTrue);
  });

  test('validasi: nol/negatif/lebih ditolak', () {
    final d = _utang().applyPayment(
      const DebtPayment(amount: 30000, date: '2026-10-05'),
    );
    expect(validatePayment(d, 0), 'nonPositive');
    expect(validatePayment(d, -5000), 'nonPositive');
    expect(validatePayment(d, 70001), 'over');
    expect(validatePayment(d, 70000), isNull);
  });

  test('applyPayment cap di sisa (backstop)', () {
    final d = _utang().applyPayment(
      const DebtPayment(amount: 999999, date: '2026-10-05'),
    );
    expect(d.remaining(), 0);
    expect(d.paidTotal, 100000);
  });

  test('total sisa utang vs piutang', () {
    final list = [
      _utang().applyPayment(
        const DebtPayment(amount: 30000, date: '2026-10-05'),
      ),
      const DebtRecord(
        id: 'p1',
        kind: 'receivable',
        name: 'Siti',
        total: 50000,
        date: '2026-10-02',
        note: '',
        payments: [],
      ),
    ];
    final t = debtTotals(list);
    expect(t.debt, 70000);
    expect(t.receivable, 50000);
  });

  test('yang lunas tak masuk total', () {
    final list = [
      _utang().applyPayment(
        const DebtPayment(amount: 100000, date: '2026-10-05'),
      ),
    ];
    final t = debtTotals(list);
    expect(t.debt, 0);
  });

  test('tryParse rusak = null', () {
    expect(DebtRecord.tryParse(null), isNull);
    expect(DebtRecord.tryParse({'id': 'x'}), isNull);
    expect(
      DebtRecord.tryParse({
        'id': 'x',
        'kind': 'ngawur',
        'name': 'A',
        'total': 1000,
        'date': '2026-10-01',
      }),
      isNull,
    );
    expect(
      DebtRecord.tryParse({
        'id': 'x',
        'kind': 'debt',
        'name': '  ',
        'total': 1000,
        'date': '2026-10-01',
      }),
      isNull,
    );
    expect(
      DebtRecord.tryParse({
        'id': 'x',
        'kind': 'debt',
        'name': 'A',
        'total': 0,
        'date': '2026-10-01',
      }),
      isNull,
    );
    expect(
      DebtRecord.tryParse({
        'id': 'x',
        'kind': 'debt',
        'name': 'A',
        'total': 1000,
        'date': 'rusak',
      }),
      isNull,
    );
  });

  test('round-trip utuh', () {
    final d = _utang().applyPayment(
      const DebtPayment(amount: 30000, date: '2026-10-05'),
    );
    final balik = DebtRecord.tryParse(d.toJson())!;
    expect(balik.name, 'Budi');
    expect(balik.kind, 'debt');
    expect(balik.note, 'Pinjam darurat');
    expect(balik.payments.length, 1);
    expect(balik.remaining(), 70000);
  });

  test('payment rusak dibuang saat parse', () {
    final d = DebtRecord.tryParse({
      'id': 'x',
      'kind': 'piutang'.replaceAll('piutang', 'receivable'),
      'name': 'A',
      'total': 1000,
      'date': '2026-10-01',
      'payments': [
        {'amount': 200, 'date': '2026-10-02'},
        {'amount': -50, 'date': '2026-10-03'},
        'rusak',
      ],
    })!;
    expect(d.payments.length, 1);
    expect(d.remaining(), 800);
  });
}
