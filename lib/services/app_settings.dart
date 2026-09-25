import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocale = 'app_locale';
const _kCurrency = 'app_currency';
const _kFontScale = 'app_font_scale';

/// Pengaturan aplikasi: bahasa, mata uang tampilan, skala font.
/// Diisi di main() sebelum runApp; layar settings mengubah + simpan.
final localeCode = ValueNotifier<String>('id');
final currencyCode = ValueNotifier<String>('IDR');
final fontScale = ValueNotifier<double>(1.0);

Future<void> loadAppSettings(SharedPreferences prefs) async {
  final loc = prefs.getString(_kLocale) ?? 'id';
  localeCode.value = (loc == 'en') ? 'en' : 'id';
  final cur = prefs.getString(_kCurrency) ?? 'IDR';
  currencyCode.value = kCurrencySymbols.containsKey(cur) ? cur : 'IDR';
  final fs = prefs.getDouble(_kFontScale) ?? 1.0;
  fontScale.value = fs.clamp(0.85, 1.3);
}

Future<void> setLocaleCode(String v) async {
  localeCode.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kLocale, v);
}

Future<void> setCurrencyCode(String v) async {
  currencyCode.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kCurrency, v);
}

Future<void> setFontScale(double v) async {
  fontScale.value = v.clamp(0.85, 1.3);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(_kFontScale, fontScale.value);
}

/// Simbol per kode mata uang (kunci juga dipakai validasi).
const kCurrencySymbols = <String, String>{
  'IDR': 'Rp',
  'USD': '\$',
  'SGD': 'S\$',
  'MYR': 'RM',
  'EUR': '€',
  'JPY': '¥',
};

/// Desimal tampilan per kode.
int kCurrencyDecimals(String code) => code == 'IDR' || code == 'JPY' ? 0 : 2;
