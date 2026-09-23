import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/wallet.dart';

void main() {
  test('wallet fromMap', () {
    final w = Wallet.fromMap({'id': '1', 'org_id': 'o1', 'name': 'Cash', 'type': 'cash'});
    expect(w.name, 'Cash');
    expect(w.orgId, 'o1');
  });
}
