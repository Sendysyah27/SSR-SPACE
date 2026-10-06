import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/budget_alerts.dart';
import 'package:ssr_space/services/budget_service.dart';
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

  test('sisipan alfabetis-awal tetap tampil (append-only created_at, I5)', () {
    // Order created_at = append-only: baru selalu di akhir.
    final alerts = ['Makan', 'Minum', 'Aqua'];
    const seen = 2;
    expect(unseenAlerts(alerts.length, seen), 1);
    final unseen = alerts.sublist(seen.clamp(0, alerts.length).toInt());
    expect(unseen, ['Aqua']);
  });

  test('parseWarnPct validasi 1–100, kosong = default 80', () {
    expect(parseWarnPct('0'), isNull);
    expect(parseWarnPct('101'), isNull);
    expect(parseWarnPct('80'), 80);
    expect(parseWarnPct(''), 80);
    expect(parseWarnPct('1'), 1);
    expect(parseWarnPct('100'), 100);
    expect(parseWarnPct('abc'), isNull);
  });
}
