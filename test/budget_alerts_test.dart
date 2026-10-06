import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/budget_alerts.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';

void main() {
  setUp(() {
    localeCode.value = 'id';
    maskAmounts.value = false;
  });

  tearDown(() {
    localeCode.value = 'id';
    maskAmounts.value = false;
  });

  test('alertLabel warn via ba_* + amt, mengandung kategori', () {
    final s = alertLabel({
      'category': 'Makan',
      'level': 'warn',
      'spent': 85000,
      'limit_amount': 100000,
    });
    expect(s.isNotEmpty, isTrue);
    expect(s, contains('Makan'));
    expect(s, contains(tr('ba_warn')));
    expect(s, contains('Rp85.000'));
    expect(s, contains('Rp100.000'));
  });

  test('alertLabel breach via ba_breach + kategori lain', () {
    final s = alertLabel({
      'category': 'Jajan',
      'level': 'breach',
      'spent': 120000,
      'limit_amount': 100000,
    });
    expect(s, contains('Jajan'));
    expect(s, contains(tr('ba_breach')));
    expect(s, contains('120%'));
  });

  test('alertLabel kategori kosong fallback cat_other', () {
    final s = alertLabel({
      'category': ' ',
      'level': 'warn',
      'spent': 1000,
      'limit_amount': 10000,
    });
    expect(s, contains(tr('cat_other')));
  });

  test('alertLabel mask menyamarkan nominal', () {
    maskAmounts.value = true;
    final s = alertLabel({
      'category': 'Makan',
      'level': 'warn',
      'spent': 85000,
      'limit_amount': 100000,
    });
    expect(s, contains('Makan'));
    expect(s, contains('•'));
    expect(s, isNot(contains('85.000')));
  });

  test('isCurrentMonth true untuk currentMonth()', () {
    expect(isCurrentMonth(currentMonth()), isTrue);
  });

  test('isCurrentMonth false untuk bulan lain', () {
    final other = currentMonth() == '2000-01' ? '2000-02' : '2000-01';
    expect(isCurrentMonth(other), isFalse);
  });

  test('baSeenKey format prefs per org per bulan', () {
    expect(baSeenKey('org1', '2026-10'), 'ba_seen_org1_2026-10');
  });

  test('unseenAlerts = count minus seen, min nol', () {
    expect(unseenAlerts(3, 1), 2);
    expect(unseenAlerts(2, 5), 0);
  });
}
