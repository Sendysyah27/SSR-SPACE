import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/currency.dart';

export 'money.dart';

const String kMaskAmountsKey = 'mask_amounts';
const String maskPlaceholder = 'Rp ••••••';

final ValueNotifier<bool> maskAmounts = ValueNotifier<bool>(false);

Future<void> loadMaskAmounts(SharedPreferences prefs) async {
  maskAmounts.value = prefs.getBool(kMaskAmountsKey) ?? false;
}

Future<void> setMaskAmounts(bool value) async {
  maskAmounts.value = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kMaskAmountsKey, value);
}

/// Nominal tampil asli (mata uang aktif), atau placeholder bila privacy
/// mode menyala. Default IDR identik dengan rp().
String amt(num value) =>
    maskAmounts.value ? CurrencyService.placeholder() : CurrencyService.format(value);
