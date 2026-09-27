import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/calm_streak.dart';

void main() {
  test('list kosong: semua false (pemanggil tampilkan ajakan)', () {
    expect(calmWeeks([], DateTime(2026, 9, 27)), List.filled(8, false));
  });

  test('transaksi minggu berjalan mengisi indeks terakhir', () {
    final now = DateTime(2026, 9, 27);
    final got = calmWeeks([DateTime(2026, 9, 26)], now);
    expect(got[7], true);
    expect(got.take(7).every((b) => !b), true);
  });

  test('batas Senin dan Minggu satu minggu yang sama', () {
    final monday = DateTime(2026, 9, 21);
    final sunday = DateTime(2026, 9, 27, 23, 59);
    final got = calmWeeks([monday, sunday], monday.add(const Duration(days: 6)));
    expect(got[7], true);
    expect(got.take(7).every((b) => !b), true);
  });

  test('transaksi future diabaikan', () {
    final now = DateTime(2026, 9, 27);
    final got = calmWeeks([DateTime(2026, 9, 28)], now);
    expect(got.every((b) => !b), true);
  });

  test('jendela 8 minggu: 7 minggu lalu terisi, 9 minggu lalu tidak', () {
    final now = DateTime(2026, 9, 27);
    final sevenAgo = DateTime(2026, 8, 4);
    final nineAgo = DateTime(2026, 7, 20);
    final gotOld = calmWeeks([sevenAgo], now);
    expect(gotOld[0], true);
    final gotTooOld = calmWeeks([nineAgo], now);
    expect(gotTooOld.every((b) => !b), true);
  });
}
