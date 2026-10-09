import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/game_challenge.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  test('senin awal minggu', () {
    expect(challengeWeekStart(d(2026, 10, 9)), d(2026, 10, 5));
  });

  test('nospend selesai dan berjalan', () {
    final now = d(2026, 10, 9);
    final done = evalChallenge(
      templateId: 'nospend3',
      txs: [
        WeekTx(date: d(2026, 10, 5), amount: 10000, category: 'Makan', isOut: true),
        WeekTx(date: d(2026, 10, 6), amount: 10000, category: 'Makan', isOut: true),
      ],
      now: now,
    );
    expect(done.status, 1);
    final run = evalChallenge(
      templateId: 'nospend3',
      txs: [
        for (var i = 5; i <= 9; i++)
          WeekTx(date: d(2026, 10, i), amount: 5000, category: 'Makan', isOut: true),
      ],
      now: now,
    );
    expect(run.status, 0);
    expect(run.progress, 0);
  });

  test('jajan gagal saat jebol, kategori lain tak ikut', () {
    final now = d(2026, 10, 9);
    final fail = evalChallenge(
      templateId: 'jajan50',
      txs: [
        WeekTx(date: d(2026, 10, 7), amount: 60000, category: 'Jajan', isOut: true),
      ],
      now: now,
    );
    expect(fail.status, 2);
    final clean = evalChallenge(
      templateId: 'jajan50',
      txs: [
        WeekTx(date: d(2026, 10, 7), amount: 90000, category: 'Makan', isOut: true),
      ],
      now: now,
    );
    expect(clean.status, 0);
    expect(clean.progress, 0);
  });

  test('log7 hitung hari unik', () {
    final run = evalChallenge(
      templateId: 'log7',
      txs: [
        for (var i = 5; i <= 9; i++)
          WeekTx(date: d(2026, 10, i), amount: 1000, category: 'Makan', isOut: true),
      ],
      now: d(2026, 10, 9),
    );
    expect(run.status, 0);
    expect(run.progress, 5);
  });
}
