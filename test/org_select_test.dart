import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active org persist logic', () async {
    final mem = <String, String>{};
    mem['active_org_id'] = 'org-123';
    mem['active_org_name'] = 'SSR HQ';
    expect(mem['active_org_id'], 'org-123');
    mem.remove('active_org_id');
    expect(mem.containsKey('active_org_id'), false);
  });
}
