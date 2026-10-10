import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/backup_json.dart';

Map<String, dynamic> sample() => {
      'app': 'ssr-space',
      'format': 1,
      'exportedAt': '2026-10-10T00:00:00Z',
      'org': {'id': 'o1', 'name': 'Rumah'},
      'wallets': [
        {'id': 'w1', 'name': 'Kas', 'type': 'cash'},
        {'id': 'w2', 'name': 'DANA', 'type': 'ewallet'},
      ],
      'transactions': [
        {
          'id': 't1',
          'org_id': 'o1',
          'type': 'out',
          'amount': 15000,
          'wallet_id': 'w1',
          'category': 'Makan',
          'note': '',
          'date': '2026-10-09',
          'code': 'TX-000001',
          'created_at': '2026-10-09T10:00:00Z',
          'source_package': 'id.dana',
          'source_hash': 'h',
        },
        {
          'type': 'transfer',
          'amount': 50000,
          'wallet_id': 'w1',
          'to_wallet_id': 'w2',
          'date': '2026-10-09',
        },
        {'type': 'out', 'amount': 0, 'wallet_id': 'w1'},
        {'type': 'aneh', 'amount': 99, 'wallet_id': 'w1'},
        {'type': 'in', 'amount': 100, 'wallet_id': 'wX'},
      ],
      'budgets': [
        {'category': 'Makan', 'month': '2026-10', 'limit_amount': 500000},
      ],
    };

void main() {
  test('build rakits struktur backup', () {
    final b = buildBackup(
      orgId: 'o1',
      orgName: 'Rumah',
      wallets: const [],
      txs: const [],
      budgets: const [],
    );
    expect(b['app'], 'ssr-space');
    expect(b['format'], 1);
    expect(jsonEncode(b), isNotNull);
  });

  test('parse terima sah, tolak rusak (fail-closed)', () {
    final p = parseBackup(sample());
    expect(p.orgName, 'Rumah');
    expect(p.txs.length, 5);
    expect(() => parseBackup(null), throwsA(isA<BackupInvalid>()));
    expect(() => parseBackup({'app': 'lain', 'format': 1}),
        throwsA(isA<BackupInvalid>()));
    expect(
        () => parseBackup({
              'app': 'ssr-space',
              'format': 99,
              'org': {'id': 'o'},
              'wallets': [],
              'transactions': [],
              'budgets': [],
            }),
        throwsA(isA<BackupInvalid>()));
  });

  test('plan: cocok nama, strip server, skip rusak', () {
    final p = parseBackup(sample());
    final plan = planRestore(
      backupWallets: p.wallets,
      backupTxs: p.txs,
      liveWallets: [
        {'id': 'live-kas', 'name': 'kas'},
      ],
    );
    // w1 cocok (case-insensitive), w2 hilang.
    expect(plan.walletMap['w1'], 'live-kas');
    expect(plan.missingWallets.keys, ['DANA']);
    // t1 siap tanpa code/hash; transfer ikut; 3 baris sampah skip.
    expect(plan.ready.length, 2);
    final first = plan.ready.first;
    expect(first.containsKey('code'), isFalse);
    expect(first.containsKey('source_package'), isFalse);
    expect(first['wallet_name'], 'Kas');
    expect(plan.ready[1]['to_wallet_name'], 'DANA');
    expect(plan.skipped, 3);
    expect(plan.capped, isFalse);
  });

  test('cap memotong + tandai', () {
    final p = parseBackup(sample());
    final plan = planRestore(
      backupWallets: p.wallets,
      backupTxs: p.txs,
      liveWallets: [
        {'id': 'a', 'name': 'Kas'},
        {'id': 'b', 'name': 'DANA'},
      ],
      cap: 1,
    );
    expect(plan.ready.length, 1);
    expect(plan.capped, isTrue);
  });
}
