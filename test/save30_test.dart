import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/save30.dart';

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  final start = DateTime(2026, 10, 1);

  test('hari tanpa belanja = hemat', () {
    final p = evalSave30(
      startYmd: '2026-10-01',
      dailyTarget: 50000,
      days: const [],
      today: start,
    );
    expect(p.dayN, 1);
    expect(p.goodDays, 1);
    expect(p.streak, 1);
  });

  test('belanja pas target = hemat', () {
    final p = evalSave30(
      startYmd: '2026-10-01',
      dailyTarget: 50000,
      days: const [SaveDay('2026-10-01', 50000)],
      today: start,
    );
    expect(p.goodDays, 1);
  });

  test('belanja lewat target = jebol, streak putus', () {
    final p = evalSave30(
      startYmd: '2026-10-01',
      dailyTarget: 50000,
      days: const [
        SaveDay('2026-10-01', 10000),
        SaveDay('2026-10-02', 90000),
      ],
      today: DateTime(2026, 10, 2),
    );
    expect(p.goodDays, 1);
    expect(p.streak, 0);
  });

  test('streak beruntun 5 hari', () {
    final p = evalSave30(
      startYmd: '2026-10-01',
      dailyTarget: 50000,
      days: const [
        SaveDay('2026-10-01', 90000),
        SaveDay('2026-10-02', 10000),
        SaveDay('2026-10-03', 20000),
      ],
      today: DateTime(2026, 10, 4),
    );
    expect(p.goodDays, 3);
    expect(p.streak, 3);
  });

  test('milestone 7 hit saat 7 hari hemat', () {
    final p = evalSave30(
      startYmd: '2026-10-01',
      dailyTarget: 50000,
      days: const [],
      today: DateTime(2026, 10, 7),
    );
    expect(p.milestonesHit, [7]);
  });

  test('newMilestones hanya yang belum dirayakan', () {
    expect(newMilestones([7], [7, 14]), [14]);
    expect(newMilestones([7, 14], [7]), isEmpty);
  });

  test('selesai setelah 30 hari, sukses bila total muat', () {
    final p = evalSave30(
      startYmd: '2026-10-01',
      dailyTarget: 50000,
      days: const [],
      today: DateTime(2026, 10, 31),
    );
    expect(p.finished, isTrue);
    expect(p.success, isTrue);
    expect(p.milestonesHit, [7, 14, 21, 30]);
  });

  test('total jebol = gagal walau 29 hari hemat', () {
    final p = evalSave30(
      startYmd: '2026-10-01',
      dailyTarget: 50000,
      days: const [SaveDay('2026-10-15', 2000000)],
      today: DateTime(2026, 10, 31),
    );
    expect(p.finished, isTrue);
    expect(p.goodDays, 29);
    expect(p.success, isFalse);
  });

  test('saran potong top-3, buang tabungan', () {
    final out = suggestCuts({
      'Makan': 900000,
      'Tabungan': 2000000,
      'Jajan': 500000,
      'Bensin': 300000,
      'Parkir': 50000,
    });
    expect(out, ['Makan', 'Jajan', 'Bensin']);
  });

  test('saran kosong bila tak ada belanja', () {
    expect(suggestCuts({}), isEmpty);
    expect(suggestCuts({'Tabungan': 100000}), isEmpty);
  });

  test('pro-rata berhenti awal', () {
    expect(save30ProRata(100000, 50000, 2), isTrue);
    expect(save30ProRata(100001, 50000, 2), isFalse);
    expect(save30ProRata(0, 50000, 0), isFalse);
  });

  test('dayN di tengah jalan', () {
    final p = evalSave30(
      startYmd: '2026-10-01',
      dailyTarget: 50000,
      days: const [],
      today: DateTime(2026, 10, 10),
    );
    expect(p.dayN, 10);
    expect(p.finished, isFalse);
  });
}
