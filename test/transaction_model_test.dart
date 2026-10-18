import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/transaction.dart';

void main() {
  Map<String, dynamic> base() => {
        'id': 't1',
        'org_id': 'o1',
        'type': 'out',
        'amount': 10000,
      };

  test('fromMap ok', () {
    final t = SaasTransaction.fromMap(base());
    expect(t.id, 't1');
    expect(t.orgId, 'o1');
    expect(t.amount, 10000.0);
  });

  test('fromMap tanpa id -> ArgumentError eksplisit', () {
    final m = base()..remove('id');
    expect(() => SaasTransaction.fromMap(m), throwsArgumentError);
  });

  test('fromMap tanpa org_id -> ArgumentError eksplisit', () {
    final m = base()..remove('org_id');
    expect(() => SaasTransaction.fromMap(m), throwsArgumentError);
  });

  test('tryFromMap baris rusak -> null (di-skip, bukan crash list)', () {
    final m = base()..remove('id');
    expect(SaasTransaction.tryFromMap(m), isNull);
  });
}
