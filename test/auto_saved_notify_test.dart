import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/auto_saved_notify.dart';
import 'package:ssr_space/utils/mask.dart';

void main() {
  setUp(() => maskAmounts.value = false);

  test('masuk satu baris', () {
    expect(
      savedBody(type: 'in', amount: 50000, app: 'DANA'),
      'Masuk Rp50.000 • DANA',
    );
  });

  test('keluar satu baris', () {
    expect(
      savedBody(type: 'out', amount: 10800, app: 'BRI'),
      'Keluar Rp10.800 • BRI',
    );
  });

  test('transfer menyebut asal ke tujuan', () {
    expect(
      savedBody(
        type: 'transfer',
        amount: 17000,
        app: 'ISAKU',
        appTo: 'GoPay',
      ),
      'Transfer Rp17.000 • ISAKU → GoPay',
    );
  });

  test('transfer tanpa tujuan = satu baris biasa', () {
    expect(
      savedBody(type: 'transfer', amount: 17000, app: 'ISAKU'),
      'Transfer Rp17.000 • ISAKU',
    );
  });

  test('id stabil per tx', () {
    expect(autoSavedId('abc'), autoSavedId('abc'));
  });
}
