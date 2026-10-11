import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/subscription_detect.dart';

SubPayment _p(
  String date,
  double amount,
  String label, {
  String type = 'out',
  bool auto = false,
  String walletId = 'w1',
  String category = '',
}) => SubPayment(
  date: date,
  amount: amount,
  label: label,
  type: type,
  auto: auto,
  walletId: walletId,
  category: category,
);

void main() {
  test('3x nominal sama tiap ~30 hari = Pasti', () {
    final c = detectSubscriptions([
      _p('2026-07-05', 54000, 'Netflix'),
      _p('2026-08-04', 54000, 'Netflix'),
      _p('2026-09-03', 54000, 'Netflix'),
    ]);
    expect(c.length, 1);
    expect(c.first.probable, isTrue);
    expect(c.first.count, 3);
    expect(c.first.amount, 54000);
    expect(c.first.label, 'Netflix');
  });

  test('2x berjarak sebulan = Mungkin', () {
    final c = detectSubscriptions([
      _p('2026-08-04', 54000, 'Netflix'),
      _p('2026-09-03', 54000, 'Netflix'),
    ]);
    expect(c.length, 1);
    expect(c.first.probable, isFalse);
    expect(c.first.count, 2);
  });

  test('nominal selang-seling tak jadi kandidat', () {
    final c = detectSubscriptions([
      _p('2026-06-05', 54000, 'Netflix'),
      _p('2026-07-05', 65000, 'Netflix'),
      _p('2026-08-05', 54000, 'Netflix'),
      _p('2026-09-05', 65000, 'Netflix'),
    ]);
    expect(c, isEmpty);
  });

  test('interval mingguan bukan langganan', () {
    final c = detectSubscriptions([
      _p('2026-09-01', 20000, 'Parkir'),
      _p('2026-09-08', 20000, 'Parkir'),
      _p('2026-09-15', 20000, 'Parkir'),
    ]);
    expect(c, isEmpty);
  });

  test('transfer dan pemasukan diabaikan', () {
    final c = detectSubscriptions([
      _p('2026-07-05', 54000, 'Netflix', type: 'transfer'),
      _p('2026-08-05', 54000, 'Netflix', type: 'in'),
      _p('2026-09-05', 54000, 'Netflix'),
    ]);
    expect(c, isEmpty);
  });

  test('label beda kapital/spasi tetap segrup', () {
    final c = detectSubscriptions([
      _p('2026-08-04', 150000, 'Spotify'),
      _p('2026-09-03', 150000, '  spotify '),
    ]);
    expect(c.length, 1);
    expect(c.first.count, 2);
  });

  test('tanggal rusak, nominal nol, label kosong dibuang', () {
    final c = detectSubscriptions([
      _p('rusak', 54000, 'Netflix'),
      _p('2026-09-03', 0, 'Netflix'),
      _p('2026-09-03', 54000, '   '),
    ]);
    expect(c, isEmpty);
  });

  test('total per bulan menjumlah semua kandidat', () {
    final c = detectSubscriptions([
      _p('2026-07-05', 54000, 'Netflix'),
      _p('2026-08-04', 54000, 'Netflix'),
      _p('2026-09-03', 54000, 'Netflix'),
      _p('2026-08-10', 150000, 'Spotify'),
      _p('2026-09-09', 150000, 'Spotify'),
    ]);
    expect(c.length, 2);
    expect(subscriptionMonthlyTotal(c), 204000);
  });

  test('known cocok tak sensitif kapital', () {
    expect(isKnownLabel('netflix', ['Netflix']), isTrue);
    expect(isKnownLabel('Spotify', ['Netflix']), isFalse);
    expect(isKnownLabel('  SPOTIFY ', ['spotify']), isTrue);
  });

  test('auto menular bila satu bayar dari auto-track', () {
    final c = detectSubscriptions([
      _p('2026-08-04', 54000, 'Netflix'),
      _p('2026-09-03', 54000, 'Netflix', auto: true),
    ]);
    expect(c.length, 1);
    expect(c.first.auto, isTrue);
  });
}
