import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/reminder_copy.dart';
import 'package:ssr_space/utils/strings.dart';

void main() {
  test('jumlah varian sesuai spec: 6 pagi, 6 malam, 2 akhir bulan', () {
    expect(morningCopyKeys.length, 6);
    expect(eveningCopyKeys.length, 6);
    expect(monthEndCopyKeys.length, 2);
  });

  test('hash tanggal stabil: tanggal sama selalu kunci sama', () {
    final d = DateTime(2026, 9, 27);
    expect(reminderKeyFor(d, 7), reminderKeyFor(d, 7));
    expect(reminderKeyFor(d, 21), reminderKeyFor(d, 21));
  });

  test('pagi vs malam dibatasi jam 15', () {
    final d = DateTime(2026, 9, 27);
    expect(morningCopyKeys.contains(reminderKeyFor(d, 7)), true);
    expect(morningCopyKeys.contains(reminderKeyFor(d, 14)), true);
    expect(eveningCopyKeys.contains(reminderKeyFor(d, 15)), true);
    expect(eveningCopyKeys.contains(reminderKeyFor(d, 21)), true);
  });

  test('akhir bulan: 3 hari terakhir pakai varian bulan', () {
    expect(isMonthEnd(DateTime(2026, 9, 27)), false);
    expect(isMonthEnd(DateTime(2026, 9, 28)), true);
    expect(isMonthEnd(DateTime(2026, 9, 30)), true);
    expect(monthEndCopyKeys.contains(reminderKeyFor(DateTime(2026, 9, 30), 7)), true);
    expect(monthEndCopyKeys.contains(reminderKeyFor(DateTime(2026, 9, 30), 21)), true);
  });

  test('jebakan Februari kabisat dan non-kabisat', () {
    expect(isMonthEnd(DateTime(2026, 2, 25)), false);
    expect(isMonthEnd(DateTime(2026, 2, 26)), true);
    expect(isMonthEnd(DateTime(2026, 2, 28)), true);
    expect(isMonthEnd(DateTime(2024, 2, 27)), true);
    expect(isMonthEnd(DateTime(2024, 2, 29)), true);
  });

  test('semua varian punya kunci ID dan EN, fallback aman', () {
    final all = [...morningCopyKeys, ...eveningCopyKeys, ...monthEndCopyKeys];
    expect(all.toSet().length, all.length);
    localeCode.value = 'id';
    for (final k in all) {
      expect(tr(k), isNot(k));
    }
    localeCode.value = 'en';
    for (final k in all) {
      expect(tr(k), isNot(k));
    }
    localeCode.value = 'id';
    expect(tr('rmc_asing_zzz'), 'rmc_asing_zzz');
  });
}
