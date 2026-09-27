import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/reports_topn.dart';
import 'package:ssr_space/services/wallet_usage.dart';

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
const _kReportsOrder = 'reports_section_order';
const _kReminderEnabled = 'reminder_enabled';
const _kReminderHour = 'reminder_hour';
const _kReminderMinute = 'reminder_minute';
const _kWidgetToday = 'widget_today';
const _kWalletUse = 'wallet_use_count';
const _kThemeChoice = 'app_theme_choice';

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
final reportSectionOrder = ValueNotifier<List<String>>(const [
  'summary',
  'recap',
  'list',
]);
final reminderEnabled = ValueNotifier<bool>(false);
final reminderHour = ValueNotifier<int>(7);
final reminderMinute = ValueNotifier<int>(0);
final widgetToday = ValueNotifier<bool>(false);
final themeChoice = ValueNotifier<String>('otomatis');

/// Hitung pemakaian dompet manual (id ke jumlah), untuk urutan dropdown.
/// Hanya naik lewat noteWalletUsed; auto-track tidak menyentuh.
final walletUseCounts = ValueNotifier<Map<String, int>>({});

Future<void> loadAppSettings(SharedPreferences prefs) async {
  final loc = prefs.getString(_kLocale) ?? 'id';
  localeCode.value = (loc == 'en') ? 'en' : 'id';
  final cur = prefs.getString(_kCurrency) ?? 'IDR';
  currencyCode.value = kCurrencySymbols.containsKey(cur) ? cur : 'IDR';
  final fs = prefs.getDouble(_kFontScale) ?? 1.0;
  fontScale.value = fs.clamp(0.85, 1.3);
  uiAnims.value = prefs.getBool(_kUiAnims) ?? true;
  final ls = prefs.getString(_kUiListStyle);
  uiListStyle.value = (ls == 'compact' || ls == 'comfortable')
      ? ls!
      : 'comfortable';
  final ds = prefs.getString(_kUiDateStyle);
  uiDateStyle.value = (ds == 'system' || ds == 'calendar' || ds == 'spinner')
      ? ds!
      : 'system';
  final hs = prefs.getString(_kUiHeroStyle);
  uiHeroStyle.value = (hs == 'emerald-calm') ? hs! : 'emerald-calm';
  homeMenuOrder.value = List<String>.of(
    prefs.getStringList(_kHomeMenuOrder) ?? [],
  );
  final defCur = prefs.getString(_kInputDefaultCurrency) ?? 'IDR';
  inputDefaultCurrency.value = kCurrencySymbols.containsKey(defCur)
      ? defCur
      : 'IDR';
  reportsTopN.value = prefs.getBool(_kReportsTopN) ?? true;
  reportSectionOrder.value = sanitizeSectionOrder(
    prefs.getStringList(_kReportsOrder),
  );
  reminderEnabled.value = prefs.getBool(_kReminderEnabled) ?? false;
  reminderHour.value = (prefs.getInt(_kReminderHour) ?? 7).clamp(0, 23);
  reminderMinute.value = (prefs.getInt(_kReminderMinute) ?? 0).clamp(0, 59);
  widgetToday.value = prefs.getBool(_kWidgetToday) ?? false;
  walletUseCounts.value = decodeUsage(prefs.getString(_kWalletUse));
  final tc = prefs.getString(_kThemeChoice);
  themeChoice.value = (tc == 'noir') ? 'noir' : 'otomatis';
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
  final nv = (v == 'compact' || v == 'comfortable') ? v : 'comfortable';
  uiListStyle.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kUiListStyle, nv);
}

Future<void> setUiDateStyle(String v) async {
  final nv = (v == 'system' || v == 'calendar' || v == 'spinner')
      ? v
      : 'system';
  uiDateStyle.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kUiDateStyle, nv);
}

Future<void> setUiHeroStyle(String v) async {
  final nv = (v == 'emerald-calm') ? v : 'emerald-calm';
  uiHeroStyle.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kUiHeroStyle, nv);
}

Future<void> setHomeMenuOrder(List<String> v) async {
  final nv = List<String>.of(v);
  homeMenuOrder.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_kHomeMenuOrder, nv);
}

Future<void> setInputDefaultCurrency(String v) async {
  final nv = kCurrencySymbols.containsKey(v) ? v : 'IDR';
  inputDefaultCurrency.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kInputDefaultCurrency, nv);
}

Future<void> setReportsTopN(bool v) async {
  reportsTopN.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kReportsTopN, v);
}

Future<void> setReportSectionOrder(List<String> v) async {
  final nv = sanitizeSectionOrder(v);
  reportSectionOrder.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_kReportsOrder, nv);
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

Future<void> setThemeChoice(String v) async {
  if (v != 'noir' && v != 'otomatis') return;
  themeChoice.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kThemeChoice, v);
}

/// Catat satu pemakaian dompet manual. Id kosong diabaikan.
/// Hanya dipanggil dari jalur simpan manual/koreksi yang sukses.
Future<void> noteWalletUsed(String id) async {
  if (id.isEmpty) return;
  walletUseCounts.value = recordUse(walletUseCounts.value, id);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kWalletUse, encodeUsage(walletUseCounts.value));
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
