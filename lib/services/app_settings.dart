import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocale = 'app_locale';
const _kCurrency = 'app_currency';
const _kFontScale = 'app_font_scale';
const _kUiAnims = 'ui_anims';
const _kUiListStyle = 'ui_list_style';
const _kUiDateStyle = 'ui_date_style';
const _kUiHeroStyle = 'ui_hero_style';
const _kHomeMenuOrder = 'home_menu_order';
const _kInputDefaultCurrency = 'input_default_currency';
const _kReportsTopN = 'reports_topn';
const _kReminderEnabled = 'reminder_enabled';
const _kReminderHour = 'reminder_hour';
const _kReminderMinute = 'reminder_minute';
const _kWidgetToday = 'widget_today';

/// Pengaturan aplikasi: bahasa, mata uang tampilan, skala font.
/// Diisi di main() sebelum runApp; layar settings mengubah + simpan.
final localeCode = ValueNotifier<String>('id');
final currencyCode = ValueNotifier<String>('IDR');
final fontScale = ValueNotifier<double>(1.0);
final uiAnims = ValueNotifier<bool>(true);
final uiListStyle = ValueNotifier<String>('comfortable');
final uiDateStyle = ValueNotifier<String>('system');
final uiHeroStyle = ValueNotifier<String>('emerald-calm');
final homeMenuOrder = ValueNotifier<List<String>>([]);
final inputDefaultCurrency = ValueNotifier<String>('IDR');
final reportsTopN = ValueNotifier<bool>(true);
final reminderEnabled = ValueNotifier<bool>(false);
final reminderHour = ValueNotifier<int>(7);
final reminderMinute = ValueNotifier<int>(0);
final widgetToday = ValueNotifier<bool>(false);

Future<void> loadAppSettings(SharedPreferences prefs) async {
  final loc = prefs.getString(_kLocale) ?? 'id';
  localeCode.value = (loc == 'en') ? 'en' : 'id';
  final cur = prefs.getString(_kCurrency) ?? 'IDR';
  currencyCode.value = kCurrencySymbols.containsKey(cur) ? cur : 'IDR';
  final fs = prefs.getDouble(_kFontScale) ?? 1.0;
  fontScale.value = fs.clamp(0.85, 1.3);
  uiAnims.value = prefs.getBool(_kUiAnims) ?? true;
  uiListStyle.value = prefs.getString(_kUiListStyle) ?? 'comfortable';
  uiDateStyle.value = prefs.getString(_kUiDateStyle) ?? 'system';
  uiHeroStyle.value = prefs.getString(_kUiHeroStyle) ?? 'emerald-calm';
  homeMenuOrder.value = prefs.getStringList(_kHomeMenuOrder) ?? [];
  final defCur = prefs.getString(_kInputDefaultCurrency) ?? 'IDR';
  inputDefaultCurrency.value = kCurrencySymbols.containsKey(defCur)
      ? defCur
      : 'IDR';
  reportsTopN.value = prefs.getBool(_kReportsTopN) ?? true;
  reminderEnabled.value = prefs.getBool(_kReminderEnabled) ?? false;
  reminderHour.value = (prefs.getInt(_kReminderHour) ?? 7).clamp(0, 23);
  reminderMinute.value = (prefs.getInt(_kReminderMinute) ?? 0).clamp(0, 59);
  widgetToday.value = prefs.getBool(_kWidgetToday) ?? false;
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

Future<void> setUiAnims(bool v) async {
  uiAnims.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kUiAnims, v);
}

Future<void> setUiListStyle(String v) async {
  uiListStyle.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kUiListStyle, v);
}

Future<void> setUiDateStyle(String v) async {
  uiDateStyle.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kUiDateStyle, v);
}

Future<void> setUiHeroStyle(String v) async {
  uiHeroStyle.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kUiHeroStyle, v);
}

Future<void> setHomeMenuOrder(List<String> v) async {
  homeMenuOrder.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_kHomeMenuOrder, v);
}

Future<void> setInputDefaultCurrency(String v) async {
  inputDefaultCurrency.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kInputDefaultCurrency, v);
}

Future<void> setReportsTopN(bool v) async {
  reportsTopN.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kReportsTopN, v);
}

Future<void> setReminderEnabled(bool v) async {
  reminderEnabled.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kReminderEnabled, v);
}

Future<void> setReminderTime(int hour, int minute) async {
  reminderHour.value = hour.clamp(0, 23);
  reminderMinute.value = minute.clamp(0, 59);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kReminderHour, reminderHour.value);
  await prefs.setInt(_kReminderMinute, reminderMinute.value);
}

Future<void> setWidgetToday(bool v) async {
  widgetToday.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kWidgetToday, v);
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
