import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/instant_correct.dart';

void main() {
  test('popup default menyala', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(InstantCorrect.popupEnabled(prefs), true);
  });

  test('pending simpan lalu hapus', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await InstantCorrect.pendingTxId(), null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_correct_tx', 'tx-1');
    expect(await InstantCorrect.pendingTxId(), 'tx-1');
    await InstantCorrect.clearPending();
    expect(await InstantCorrect.pendingTxId(), null);
  });

  test('summary keluar/masuk', () {
    expect(
      InstantCorrect.summary(type: 'in', amount: 50000, app: 'DANA'),
      'Masuk Rp50.000 • DANA',
    );
    expect(
      InstantCorrect.summary(type: 'out', amount: 10800, app: 'BRI'),
      'Keluar Rp10.800 • BRI',
    );
    expect(
      InstantCorrect.summary(type: 'transfer', amount: 17000, app: 'SeaBank'),
      'Transfer Rp17.000 • SeaBank',
    );
  });
}
