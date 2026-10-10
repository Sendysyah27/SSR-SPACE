import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/realtime_sync.dart';

void main() {
  test('topik unik per org', () {
    expect(realtimeTopic('abc'), 'org-sync-abc');
    expect(realtimeTopic('abc') == realtimeTopic('abd'), isFalse);
  });

  test('hanya 4 tabel sync yang didengar', () {
    for (final t in [
      'transactions',
      'org_members',
      'wallets',
      'budgets',
    ]) {
      expect(isSyncTable(t), isTrue, reason: t);
    }
    expect(isSyncTable('audit_logs'), isFalse);
    expect(isSyncTable('heartbeat'), isFalse);
    expect(isSyncTable(''), isFalse);
  });
}
