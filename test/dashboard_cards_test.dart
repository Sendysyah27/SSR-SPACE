import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/dashboard_cards.dart';

void main() {
  test('default lima kartu berurutan', () {
    expect(kDashboardDefault, [
      'budget',
      'fitur',
      'utang',
      'allowance',
      'networth',
    ]);
  });

  test('parse rusak jatuh ke default', () {
    expect(parseDashboardOrder(null), kDashboardDefault);
    expect(parseDashboardOrder('ngawur'), kDashboardDefault);
    expect(
      parseDashboardOrder(['fitur', 'asing', 'budget']),
      ['fitur', 'budget', 'utang', 'allowance', 'networth'],
    );
    expect(parseDashboardOrder([]), kDashboardDefault);
  });

  test('order lama tanpa allowance dilengkapi di belakang', () {
    expect(
      parseDashboardOrder(['utang', 'budget', 'fitur']),
      ['utang', 'budget', 'fitur', 'allowance', 'networth'],
    );
  });

  test('order lama tanpa networth dilengkapi di belakang', () {
    expect(
      parseDashboardOrder(['utang', 'budget', 'fitur', 'allowance']),
      ['utang', 'budget', 'fitur', 'allowance', 'networth'],
    );
  });

  test('round-trip via stringList prefs', () {
    final order = ['utang', 'budget', 'fitur', 'allowance', 'networth'];
    expect(parseDashboardOrder(List.of(order)), order);
  });

  test('geser naik-turun + jepit batas', () {
    expect(
      moveDashboardCard(['a', 'b', 'c'], 'b', -1),
      ['b', 'a', 'c'],
    );
    expect(
      moveDashboardCard(['a', 'b', 'c'], 'b', 1),
      ['a', 'c', 'b'],
    );
    expect(moveDashboardCard(['a', 'b'], 'a', -1), ['a', 'b']);
    expect(moveDashboardCard(['a', 'b'], 'b', 1), ['a', 'b']);
    expect(moveDashboardCard(['a'], 'asing', 1), ['a']);
  });

  test('sembunyi tampilkan', () {
    expect(isDashboardHidden({'fitur'}, 'fitur'), isTrue);
    expect(isDashboardHidden({'fitur'}, 'budget'), isFalse);
  });

  test('lampu: hijau emas merah', () {
    expect(budgetLight(spent: 30, limit: 100, warnPct: 80), 'green');
    expect(budgetLight(spent: 85, limit: 100, warnPct: 80), 'gold');
    expect(budgetLight(spent: 100, limit: 100, warnPct: 80), 'red');
    expect(budgetLight(spent: 150, limit: 100, warnPct: 80), 'red');
    expect(budgetLight(spent: 0, limit: 0, warnPct: 80), 'green');
  });
}
