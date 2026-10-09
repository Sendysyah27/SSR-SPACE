import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/utils/strings.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    localeCode.value = 'id';
    currencyCode.value = 'IDR';
    fontScale.value = 1.0;
    CurrencyService.rates = {};
  });

  test('tr default Indonesia, fallback kunci', () {
    expect(tr('tx_in'), 'Masuk');
    expect(tr('tidak_ada_kunci_ini'), 'tidak_ada_kunci_ini');
  });

  test('tr English saat locale en', () {
    localeCode.value = 'en';
    expect(tr('tx_in'), 'Income');
    expect(tr('tx_empty_t'), 'No transactions this month yet');
    expect(tr('m09'), 'September');
  });

  test('format IDR default identik rp', () {
    expect(CurrencyService.format(1500000), 'Rp1.500.000');
    expect(CurrencyService.placeholder(), 'Rp ••••••');
  });

  test('format US pakai koma', () {
    numberFormat.value = 'us';
    expect(CurrencyService.format(1500000), 'Rp1,500,000');
    numberFormat.value = 'id';
    expect(CurrencyService.format(1500000), 'Rp1.500.000');
  });

  test('format USD pakai kurs cache + simbol', () {
    CurrencyService.rates = {'USD': 0.00006};
    currencyCode.value = 'USD';
    expect(CurrencyService.convert(1000000), 60.0);
    expect(CurrencyService.format(1000000), '\$60.00');
    expect(CurrencyService.placeholder(), '\$ ••••••');
    expect(CurrencyService.toIdr(60), closeTo(1000000, 1));
  });

  test('tanpa kurs jatuh kembali ke IDR', () {
    currencyCode.value = 'USD';
    expect(CurrencyService.convert(5000), 5000);
    expect(CurrencyService.toIdr(5), 5);
  });

  test('font scale dijepit 0.85-1.3', () async {
    await setFontScale(9);
    expect(fontScale.value, 1.3);
    await setFontScale(0.1);
    expect(fontScale.value, 0.85);
  });
}
