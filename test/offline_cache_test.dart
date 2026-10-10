import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/budget_service.dart';
import 'package:ssr_space/services/offline_cache.dart';

SaasTransaction tx() => SaasTransaction(
      id: 't1',
      orgId: 'o1',
      type: 'out',
      amount: 25000,
      walletId: 'w1',
      category: 'Makan > Kopi',
      note: 'n',
      date: '2026-10-10',
      code: 'TX-000001',
    );

void main() {
  test('tx round-trip utuh', () {
    final back = SaasTransaction.fromMap(tx().toMap());
    expect(back.id, 't1');
    expect(back.amount, 25000);
    expect(back.category, 'Makan > Kopi');
    expect(back.code, 'TX-000001');
    expect(back.toWalletId, isNull);
  });

  test('budget round-trip utuh', () {
    final m = BudgetMonth(
      items: [Budget(category: 'Makan', limit: 100000, spent: 25000)],
      totalIn: 500000,
    );
    final back = BudgetMonth.fromMap(m.toMap());
    expect(back.totalIn, 500000);
    expect(back.items.single.spent, 25000);
    expect(back.items.single.warnPct, 80);
  });

  test('isNetworkError: jaringan ya, server/bentuk tidak', () {
    expect(isNetworkError(const SocketException('x')), isTrue);
    expect(isNetworkError(const HttpException('x')), isTrue);
    expect(isNetworkError(TimeoutException('x')), isTrue);
    expect(isNetworkError(const FormatException('x')), isFalse);
    expect(isNetworkError(StateError('x')), isFalse);
  });

  test('flag offline/online jujur', () {
    netOnline.value = true;
    markOffline();
    expect(netOnline.value, isFalse);
    markOffline();
    expect(netOnline.value, isFalse);
    markOnline();
    expect(netOnline.value, isTrue);
    netOnline.value = true;
  });

  test('cache tx tulis-baca + rusak = null', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await readTxCache('o1', '2026-10'), isNull);
    await writeTxCache('o1', '2026-10', [tx().toMap()]);
    final back = await readTxCache('o1', '2026-10');
    expect(back?.length, 1);
    expect(
      SaasTransaction.fromMap(back!.first).amount,
      25000,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('off_tx_o1_2026-10', 'rusak{{{');
    expect(await readTxCache('o1', '2026-10'), isNull);
  });

  test('cache mix + budget tulis-baca', () async {
    SharedPreferences.setMockInitialValues({});
    await writeMixCache('o1', '2026-10', null, {
      'rows': [
        {'t': 'in', 'c': 'Gaji', 's': 5000, 'n': 1},
      ],
      'total_n': 1,
    });
    final mix = await readMixCache('o1', '2026-10', null);
    expect(mix?['total_n'], 1);
    await writeBudgetCache('o1', '2026-10', {
      'items': [
        {'category': 'Makan', 'limit_amount': 100000},
      ],
      'totalIn': 500000,
    });
    final bud = await readBudgetCache('o1', '2026-10');
    expect(BudgetMonth.fromMap(bud!).totalIn, 500000);
  });
}
