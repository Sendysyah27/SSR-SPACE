import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/transaction_service.dart';

void main() {
  test('date null diganti hari ini, bukan null (default DB tak dipakai utk null eksplisit)', () {
    final p = txInsertPayload(
      orgId: 'org-1',
      type: 'in',
      amount: 25000,
      date: null,
      now: DateTime(2026, 9, 24),
    );
    expect(p['date'], '2026-09-24');
    expect(p['date'], isNotNull);
  });

  test('date non-null dipertahankan (auto-track / edit)', () {
    final p = txInsertPayload(
      orgId: 'org-1',
      type: 'out',
      amount: 1000,
      date: '2026-01-15',
      now: DateTime(2026, 9, 24),
    );
    expect(p['date'], '2026-01-15');
  });

  test('payload memuat field inti insert', () {
    final p = txInsertPayload(
      orgId: 'org-1',
      type: 'in',
      amount: 25000,
      walletId: 'w1',
      category: 'BONUS',
      note: 'Insentif',
      createdBy: 'u1',
    );
    expect(p['org_id'], 'org-1');
    expect(p['type'], 'in');
    expect(p['amount'], 25000);
    expect(p['wallet_id'], 'w1');
    expect(p['category'], 'BONUS');
    expect(p['note'], 'Insentif');
    expect(p['created_by'], 'u1');
    expect(p['date'], isNotNull);
  });

  test('update payload omits date null (biar kolom tidak di-set NULL)', () {
    final withDate = txUpdatePayload(type: 'in', amount: 1, date: '2026-09-24');
    expect(withDate['date'], '2026-09-24');
    final withoutDate = txUpdatePayload(type: 'in', amount: 1, date: null);
    expect(withoutDate.containsKey('date'), isFalse);
  });
}
