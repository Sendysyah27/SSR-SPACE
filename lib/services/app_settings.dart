import 'dart:async';
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
const _kWeeklyEnabled = 'weekly_enabled';
const _kWeeklyWeekday = 'weekly_weekday';
const _kWeeklyHour = 'weekly_hour';
const _kWeeklyMinute = 'weekly_minute';
const _kWidgetToday = 'widget_today';
const _kWalletUse = 'wallet_use_count';
const _kThemeChoice = 'app_theme_choice';
const _kThemeDayStart = 'app_theme_day_start';
const _kThemeNightStart = 'app_theme_night_start';
const _kNumberFormat = 'app_number_format';
const _kDefaultWallet = 'app_default_wallet';
const _kWeekStart = 'app_week_start';
const _kLockTimeout = 'app_lock_timeout';
const _kBiometric = 'app_biometric';
const _kCardTheme = 'app_card_theme';
const _kHomePeriod = 'home_period';
const _kHomeDefaultPeriod = 'home_default_period';
const _kBalanceShowDecimal = 'balance_show_decimal';

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
final weeklyEnabled = ValueNotifier<bool>(false);
final weeklyWeekday = ValueNotifier<int>(7);
final weeklyHour = ValueNotifier<int>(20);
final weeklyMinute = ValueNotifier<int>(0);
final widgetToday = ValueNotifier<bool>(false);
/// Pilihan tema: 'terang' | 'gelap' | 'otomatis' (auto-switch terjadwal).
final themeChoice = ValueNotifier<String>('otomatis');

/// Jam mulai mode terang (0-23) dan jam mulai mode gelap (0-23) untuk
/// mode 'otomatis'. Default: terang 06:00-18:00, gelap 18:00-06:00.
final themeDayStart = ValueNotifier<int>(6);
final themeNightStart = ValueNotifier<int>(18);

/// Tema efektif hasil resolusi: 'terang' | 'gelap'.
/// Mode 'otomatis' dievaluasi dari jam sekarang; mode manual = pilihan.
final themeEffective = ValueNotifier<String>('terang');

/// Tema gradient kartu saldo: 'navy' | 'ocean' | 'midnight' | 'steel'.
final cardTheme = ValueNotifier<String>('navy');

/// Periode tampil Beranda ala Ollo: 'day' | 'week' | 'month' | 'year' |
/// 'calendar'. UI + state saja (belum di-wire ke pemuatan data Beranda
/// yang tetap berbasis bulan via MonthPicker).
final homePeriod = ValueNotifier<String>('month');

/// Periode default Beranda saat dibuka: 'day' | 'week' | 'month' | 'year'.
/// Dipakai sebagai nilai awal homePeriod bila belum ada pilihan tersimpan.
final homeDefaultPeriod = ValueNotifier<String>('month');

/// Tampilkan desimal nominal (default true = perilaku sekarang).
/// Di-wire di CurrencyService.format (sentral, berlaku untuk semua amt()).
final balanceShowDecimal = ValueNotifier<bool>(true);

/// Format angka: 'id' (1.000.000) atau 'us' (1,000,000).
final numberFormat = ValueNotifier<String>('id');

/// Dompet default form catat (id wallet, '' = tanpa default).
final defaultWalletId = ValueNotifier<String>('');

/// Hari awal minggu: 1 Senin, 7 Minggu.
final weekStart = ValueNotifier<int>(1);

/// Auto-lock menit: 1, 5, 15, atau 30.
final lockTimeoutMinutes = ValueNotifier<int>(5);

/// Biometrik sebagai alternatif PIN (default MATI = opt-in eksplisit).
final biometricEnabled = ValueNotifier<bool>(false);

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
  final ct = prefs.getString(_kCardTheme);
  cardTheme.value = (ct == 'navy' ||
          ct == 'ocean' ||
          ct == 'midnight' ||
          ct == 'steel')
      ? ct!
      : 'navy';
  final hdp = prefs.getString(_kHomeDefaultPeriod);
  homeDefaultPeriod.value =
      (hdp == 'day' || hdp == 'week' || hdp == 'month' || hdp == 'year')
          ? hdp!
          : 'month';
  final hp = prefs.getString(_kHomePeriod);
  homePeriod.value = (hp == 'day' ||
          hp == 'week' ||
          hp == 'month' ||
          hp == 'year' ||
          hp == 'calendar')
      ? hp!
      : homeDefaultPeriod.value;
  balanceShowDecimal.value = prefs.getBool(_kBalanceShowDecimal) ?? true;
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
  weeklyEnabled.value = prefs.getBool(_kWeeklyEnabled) ?? false;
  weeklyWeekday.value = (prefs.getInt(_kWeeklyWeekday) ?? 7).clamp(1, 7);
  weeklyHour.value = (prefs.getInt(_kWeeklyHour) ?? 20).clamp(0, 23);
  weeklyMinute.value = (prefs.getInt(_kWeeklyMinute) ?? 0).clamp(0, 59);
  widgetToday.value = prefs.getBool(_kWidgetToday) ?? false;
  walletUseCounts.value = decodeUsage(prefs.getString(_kWalletUse));
  // Migrasi sekali jalan: nilai lama 'noir' -> 'gelap', ditulis balik.
  final tc = prefs.getString(_kThemeChoice);
  if (tc == 'noir') {
    themeChoice.value = 'gelap';
    await prefs.setString(_kThemeChoice, 'gelap');
  } else if (tc == 'terang' || tc == 'gelap' || tc == 'otomatis') {
    themeChoice.value = tc!;
  } else {
    themeChoice.value = 'otomatis';
  }
  themeDayStart.value = (prefs.getInt(_kThemeDayStart) ?? 6).clamp(0, 23);
  themeNightStart.value =
      (prefs.getInt(_kThemeNightStart) ?? 18).clamp(0, 23);
  final nf = prefs.getString(_kNumberFormat);
  numberFormat.value = (nf == 'us') ? 'us' : 'id';
  defaultWalletId.value = prefs.getString(_kDefaultWallet) ?? '';
  final ws = prefs.getInt(_kWeekStart) ?? 1;
  weekStart.value = (ws == 7) ? 7 : 1;
  final lt = prefs.getInt(_kLockTimeout) ?? 5;
  lockTimeoutMinutes.value =
      (lt == 1 || lt == 5 || lt == 15 || lt == 30) ? lt : 5;
  biometricEnabled.value = prefs.getBool(_kBiometric) ?? false;
  syncThemeAutoTimer();
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

Future<void> setCardTheme(String v) async {
  final nv =
      (v == 'navy' || v == 'ocean' || v == 'midnight' || v == 'steel')
          ? v
          : 'navy';
  cardTheme.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kCardTheme, nv);
}

Future<void> setHomePeriod(String v) async {
  final nv = (v == 'day' ||
          v == 'week' ||
          v == 'month' ||
          v == 'year' ||
          v == 'calendar')
      ? v
      : 'month';
  homePeriod.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kHomePeriod, nv);
}

Future<void> setHomeDefaultPeriod(String v) async {
  final nv =
      (v == 'day' || v == 'week' || v == 'month' || v == 'year') ? v : 'month';
  homeDefaultPeriod.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kHomeDefaultPeriod, nv);
}

Future<void> setBalanceShowDecimal(bool v) async {
  balanceShowDecimal.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kBalanceShowDecimal, v);
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

Future<void> setWeeklyEnabled(bool v) async {
  weeklyEnabled.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kWeeklyEnabled, v);
}

Future<void> setWeeklyDay(int weekday) async {
  weeklyWeekday.value = weekday.clamp(1, 7);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kWeeklyWeekday, weeklyWeekday.value);
}

Future<void> setWeeklyTime(int hour, int minute) async {
  weeklyHour.value = hour.clamp(0, 23);
  weeklyMinute.value = minute.clamp(0, 59);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kWeeklyHour, weeklyHour.value);
  await prefs.setInt(_kWeeklyMinute, weeklyMinute.value);
}

Future<void> setWidgetToday(bool v) async {
  widgetToday.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kWidgetToday, v);
}

Future<void> setThemeChoice(String v) async {
  if (v != 'terang' && v != 'gelap' && v != 'otomatis') return;
  themeChoice.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kThemeChoice, v);
  syncThemeAutoTimer();
}

/// Jam mulai mode terang (0-23), hanya dipakai mode 'otomatis'.
Future<void> setThemeDayStart(int v) async {
  final nv = v.clamp(0, 23);
  themeDayStart.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kThemeDayStart, nv);
  refreshEffectiveTheme();
}

/// Jam mulai mode gelap (0-23), hanya dipakai mode 'otomatis'.
Future<void> setThemeNightStart(int v) async {
  final nv = v.clamp(0, 23);
  themeNightStart.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kThemeNightStart, nv);
  refreshEffectiveTheme();
}

// --- Auto-switch tema terjadwal -------------------------------------
// Mode 'otomatis': terang pukul [themeDayStart] s/d sebelum
// [themeNightStart]; gelap di luar rentang itu. Timer 1 menit menyegarkan
// [themeEffective]; timer hanya hidup saat mode 'otomatis' (dibatalkan
// saat manual) agar ringan dan tidak bocor.

Timer? _themeTimer;

/// Jam [hour] (0-23) termasuk rentang terang? Rentang boleh melintasi
/// tengah malam (mis. terang 20:00 s/d 06:00). Batas sama = terang
/// seharian. Murni (bisa di-test).
bool isThemeDayHour(int hour, int dayStart, int nightStart) {
  final h = hour.clamp(0, 23);
  final ds = dayStart.clamp(0, 23);
  final ns = nightStart.clamp(0, 23);
  if (ds == ns) return true;
  if (ds < ns) return h >= ds && h < ns;
  return h >= ds || h < ns;
}

/// Resolusi tema efektif dari pilihan + jam. Murni (bisa di-test).
String resolveEffectiveTheme({
  required String choice,
  required int hour,
  required int dayStart,
  required int nightStart,
}) {
  if (choice == 'gelap') return 'gelap';
  if (choice == 'terang') return 'terang';
  return isThemeDayHour(hour, dayStart, nightStart) ? 'terang' : 'gelap';
}

/// Hitung ulang tema efektif dari state sekarang; notify hanya bila
/// nilai berubah (ValueNotifier tidak rebuild berlebihan).
void refreshEffectiveTheme() {
  final eff = resolveEffectiveTheme(
    choice: themeChoice.value,
    hour: DateTime.now().hour,
    dayStart: themeDayStart.value,
    nightStart: themeNightStart.value,
  );
  if (themeEffective.value != eff) themeEffective.value = eff;
}

/// Sinkronkan timer auto-switch dengan mode; dipanggil setelah load prefs
/// dan setiap perubahan pilihan tema.
void syncThemeAutoTimer() {
  if (themeChoice.value == 'otomatis') {
    _themeTimer ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => refreshEffectiveTheme(),
    );
  } else {
    _themeTimer?.cancel();
    _themeTimer = null;
  }
  refreshEffectiveTheme();
}

/// Hentikan timer auto-switch. Dipakai test; app tidak pernah memanggil
/// (timer level-app, dibatalkan otomatis saat mode manual).
@visibleForTesting
void stopThemeAutoTimer() {
  _themeTimer?.cancel();
  _themeTimer = null;
}

Future<void> setNumberFormat(String v) async {
  final nv = (v == 'us') ? 'us' : 'id';
  numberFormat.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kNumberFormat, nv);
}

Future<void> setDefaultWalletId(String v) async {
  defaultWalletId.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kDefaultWallet, v);
}

Future<void> setWeekStart(int v) async {
  final nv = (v == 7) ? 7 : 1;
  weekStart.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kWeekStart, nv);
}

Future<void> setLockTimeoutMinutes(int v) async {
  final nv = (v == 1 || v == 5 || v == 15 || v == 30) ? v : 5;
  lockTimeoutMinutes.value = nv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kLockTimeout, nv);
}

/// Biometrik on/off (opt-in; default mati). Tanpa validasi perangkat di
/// sini — LockScreen cek dukungan saat dipakai (fail-closed).
Future<void> setBiometricEnabled(bool v) async {
  biometricEnabled.value = v;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kBiometric, v);
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
