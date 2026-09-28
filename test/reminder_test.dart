import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/reminder_schedule.dart';

void main() {
  test('jam masih di depan hari ini, tidak geser hari', () {
    final now = DateTime(2026, 9, 26, 6, 0);
    expect(nextDaily(7, 0, now), DateTime(2026, 9, 26, 7, 0));
  });

  test('jam sudah lewat, geser ke besok jam yang sama', () {
    final now = DateTime(2026, 9, 26, 8, 30);
    expect(nextDaily(7, 0, now), DateTime(2026, 9, 27, 7, 0));
  });

  test('tepat sama dengan sekarang, geser ke besok', () {
    final now = DateTime(2026, 9, 26, 7, 0);
    expect(nextDaily(7, 0, now), DateTime(2026, 9, 27, 7, 0));
  });

  test('di luar rentang dijepit, tidak throw', () {
    final now = DateTime(2026, 9, 26, 6, 0);
    expect(nextDaily(99, -5, now), DateTime(2026, 9, 26, 23, 0));
    expect(nextDaily(-3, 999, now), DateTime(2026, 9, 27, 0, 59));
  });

  test('peta offset ke zona Indonesia', () {
    expect(zoneForOffsetHours(7), 'Asia/Jakarta');
    expect(zoneForOffsetHours(8), 'Asia/Makassar');
    expect(zoneForOffsetHours(9), 'Asia/Jayapura');
    expect(zoneForOffsetHours(0), 'UTC');
  });

  test('mingguan: hari sama jam masih di depan = hari ini', () {
    final now = DateTime(2026, 9, 28, 10, 0); // Senin
    expect(nextWeekly(1, 12, 0, now), DateTime(2026, 9, 28, 12, 0));
  });

  test('mingguan: hari sama jam lewat = minggu depan', () {
    final now = DateTime(2026, 9, 28, 10, 0); // Senin
    expect(nextWeekly(1, 7, 0, now), DateTime(2026, 10, 5, 7, 0));
  });

  test('mingguan: beda hari = hari itu minggu ini', () {
    final now = DateTime(2026, 9, 28, 10, 0); // Senin
    expect(nextWeekly(7, 20, 0, now), DateTime(2026, 10, 4, 20, 0));
  });

  test('mingguan: tepat sama dengan sekarang = minggu depan', () {
    final now = DateTime(2026, 9, 28, 20, 0);
    expect(nextWeekly(1, 20, 0, now), DateTime(2026, 10, 5, 20, 0));
  });

  test('mingguan: di luar rentang dijepit, tidak throw', () {
    final now = DateTime(2026, 9, 28, 10, 0); // Senin
    expect(nextWeekly(0, 99, -5, now), DateTime(2026, 9, 28, 23, 0));
  });
}
