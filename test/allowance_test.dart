import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/allowance.dart';

void main() {
  test('sisa 3jt 15 hari = 200rb per hari', () {
    expect(dailyAllowance(remaining: 3000000, daysLeft: 15), 200000);
  });

  test('sisa hari inklusif (hari ini dihitung)', () {
    // Oktober: 31 hari. Tgl 17 -> sisa 15 hari (17..31).
    expect(daysLeftInMonth(DateTime(2026, 10, 17)), 15);
    // Hari terakhir -> 1.
    expect(daysLeftInMonth(DateTime(2026, 10, 31)), 1);
    // Februari kabisat.
    expect(daysLeftInMonth(DateTime(2024, 2, 28)), 2);
  });

  test('sisa nol/negatif = lampu merah', () {
    expect(
      allowanceLight(remaining: 0, avgDailyOut: 50000, daysLeft: 10),
      'red',
    );
    expect(
      allowanceLight(remaining: -1000, avgDailyOut: 0, daysLeft: 10),
      'red',
    );
  });

  test('proyeksi boncos = kuning, aman = hijau', () {
    // Pace 100rb/hari x 10 hari = 1jt > sisa 500rb -> kuning.
    expect(
      allowanceLight(remaining: 500000, avgDailyOut: 100000, daysLeft: 10),
      'gold',
    );
    // Pace 30rb/hari x 10 = 300rb <= 500rb -> hijau.
    expect(
      allowanceLight(remaining: 500000, avgDailyOut: 30000, daysLeft: 10),
      'green',
    );
    // Pas-pasan tepat = hijau (tak boncos).
    expect(
      allowanceLight(remaining: 500000, avgDailyOut: 50000, daysLeft: 10),
      'green',
    );
  });
}
