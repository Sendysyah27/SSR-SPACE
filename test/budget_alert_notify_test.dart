import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/budget_alert_notify.dart';

Map<String, dynamic> row(String cat, String lvl) => {
      'month': '2026-10',
      'category': cat,
      'level': lvl,
      'spent': 85000,
      'limit_amount': 100000,
    };

void main() {
  test('kunci unik per bulan|kategori|level', () {
    expect(alertNotifyKey('2026-10', 'Makan', 'warn'),
        '2026-10|Makan|warn');
    expect(alertNotifyKey('2026-10', 'Makan', 'warn') ==
        alertNotifyKey('2026-10', 'Makan', 'breach'), isFalse);
    expect(alertNotifyKey('2026-10', 'Makan', 'warn') ==
        alertNotifyKey('2026-11', 'Makan', 'warn'), isFalse);
  });

  test('saring yang sudah tampil (anti-spam 1x)', () {
    final rows = [row('Makan', 'warn'), row('Jajan', 'warn')];
    expect(unseenAlertRows(rows, {}).length, 2);
    expect(
        unseenAlertRows(rows, {'2026-10|Makan|warn'}).length, 1);
    expect(
        unseenAlertRows(rows, {'2026-10|Makan|warn', '2026-10|Jajan|warn'}),
        isEmpty);
  });

  test('kategori kosong tetap berkunci (tak bocor ke semua)', () {
    final rows = [row('', 'warn')];
    expect(unseenAlertRows(rows, {}).length, 1);
    expect(unseenAlertRows(rows, {'2026-10||warn'}).length, 0);
  });
}
