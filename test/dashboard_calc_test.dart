import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/core/saas/dashboard_service.dart';
import 'package:ssr_space/models/transaction.dart';

SaasTransaction _t(String type, double amount, [String? cat]) => SaasTransaction(
      id: 'x', orgId: 'o', type: type, amount: amount, category: cat, date: '2026-09-24',
    );

void main() {
  test('compute dashboard totals', () {
    final d = computeDashboard([_t('in', 1000), _t('out', 400, 'Makan'), _t('out', 100, 'Makan')]);
    expect(d.totalIn, 1000);
    expect(d.totalOut, 500);
    expect(d.balance, 500);
    expect(d.outByCategory['Makan'], 500);
    expect(d.recent.length, 3);
  });
}
