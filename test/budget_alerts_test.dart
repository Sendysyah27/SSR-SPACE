import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/budget_alerts.dart';
import 'package:ssr_space/services/month.dart';

void main() {
  test('alertLabel warn mengandung kategori', () {
    final s = alertLabel({
      'category': 'Makan',
      'level': 'warn',
      'spent': 85000,
      'limit_amount': 100000,
    });
    expect(s.isNotEmpty, isTrue);
    expect(s, contains('Makan'));
  });

  test('alertLabel breach mengandung kategori', () {
    final s = alertLabel({
      'category': 'Jajan',
      'level': 'breach',
      'spent': 120000,
      'limit_amount': 100000,
    });
    expect(s.isNotEmpty, isTrue);
    expect(s, contains('Jajan'));
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
