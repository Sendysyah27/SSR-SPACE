import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/utils/mask.dart';

void main() {
  test('amt tampil asli saat mask mati', () {
    maskAmounts.value = false;
    expect(amt(1500000), 'Rp 1.500.000');
  });

  test('amt menyamar saat mask menyala', () {
    maskAmounts.value = true;
    expect(amt(1500000), maskPlaceholder);
    maskAmounts.value = false;
  });

  test('default mask mati saat prefs kosong', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await loadMaskAmounts(prefs);
    expect(maskAmounts.value, false);
    expect(amt(500), 'Rp 500');
  });

  test('mask disimpan di prefs dan terbaca balik', () async {
    SharedPreferences.setMockInitialValues({kMaskAmountsKey: true});
    final prefs = await SharedPreferences.getInstance();
    await loadMaskAmounts(prefs);
    expect(maskAmounts.value, true);
    expect(amt(500), maskPlaceholder);
    maskAmounts.value = false;
  });
}
