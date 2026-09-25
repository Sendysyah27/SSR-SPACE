import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'money.dart';

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

/// Nominal tampil asli, atau placeholder bila privacy mode menyala.
String amt(num value) => maskAmounts.value ? maskPlaceholder : rp(value);
