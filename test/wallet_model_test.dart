import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/wallet.dart';

void main() {
  test('wallet fromMap', () {
    final w = Wallet.fromMap({'id': '1', 'org_id': 'o1', 'name': 'Cash', 'type': 'cash'});
    expect(w.name, 'Cash');
    expect(w.orgId, 'o1');
  });

  test('wallet fromMap tanpa id -> ArgumentError (bukan string "null")', () {
    expect(
        () => Wallet.fromMap({'org_id': 'o1', 'name': 'Cash', 'type': 'cash'}),
        throwsArgumentError);
  });

  test('wallet fromMap tanpa org_id -> ArgumentError', () {
    expect(
        () => Wallet.fromMap({'id': '1', 'name': 'Cash', 'type': 'cash'}),
        throwsArgumentError);
  });
}
