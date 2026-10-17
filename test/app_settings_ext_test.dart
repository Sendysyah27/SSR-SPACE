import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/app_settings.dart';

void main() {
  tearDown(() {
    stopThemeAutoTimer();
  });
  test('defaults fail-safe saat prefs kosong', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await loadAppSettings(p);
    expect(uiAnims.value, true);
    expect(uiListStyle.value, 'comfortable');
    expect(uiDateStyle.value, 'system');
    expect(uiHeroStyle.value, 'emerald-calm');
    expect(reportsTopN.value, true);
    expect(reminderEnabled.value, false);
    expect(reminderHour.value, 7);
    expect(reminderMinute.value, 0);
    expect(widgetToday.value, false);
    expect(inputDefaultCurrency.value, 'IDR');
  });

  test('opsi baru fail-safe + persist', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await loadAppSettings(p);    expect(numberFormat.value, 'id');
    expect(defaultWalletId.value, '');
    expect(weekStart.value, 1);
    expect(lockTimeoutMinutes.value, 5);
    expect(biometricEnabled.value, false);
    await setBiometricEnabled(true);
    expect(biometricEnabled.value, true);
    await setBiometricEnabled(false);
    expect(biometricEnabled.value, false);
    await setNumberFormat('us');
    expect(numberFormat.value, 'us');
    await setNumberFormat('xx');
    expect(numberFormat.value, 'id');
    await setDefaultWalletId('w1');
    expect(defaultWalletId.value, 'w1');
    await setWeekStart(7);
    expect(weekStart.value, 7);
    await setWeekStart(3);
    expect(weekStart.value, 1);
    await setLockTimeoutMinutes(15);
    expect(lockTimeoutMinutes.value, 15);
    await setLockTimeoutMinutes(99);
    expect(lockTimeoutMinutes.value, 5);
    SharedPreferences.setMockInitialValues({
      'app_number_format': 'us',
      'app_default_wallet': 'w9',
      'app_week_start': 7,
      'app_lock_timeout': 30,
      'app_biometric': true,
    });
    final p2 = await SharedPreferences.getInstance();
    await loadAppSettings(p2);
    expect(numberFormat.value, 'us');
    expect(defaultWalletId.value, 'w9');
    expect(weekStart.value, 7);
    expect(lockTimeoutMinutes.value, 30);
    expect(biometricEnabled.value, true);
  });

  test('theme choice fail-safe + persist', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await loadAppSettings(p);
    expect(themeChoice.value, 'otomatis');
    await setThemeChoice('terang');
    expect(themeChoice.value, 'terang');
    await setThemeChoice('gelap');
    expect(themeChoice.value, 'gelap');
    await setThemeChoice('invalid');
    expect(themeChoice.value, 'gelap');
    await setThemeChoice('otomatis');
    expect(themeChoice.value, 'otomatis');
    await setThemeChoice('invalid');
    expect(themeChoice.value, 'otomatis');
    SharedPreferences.setMockInitialValues({'app_theme_choice': 'gelap'});
    final p2 = await SharedPreferences.getInstance();
    await loadAppSettings(p2);
    expect(themeChoice.value, 'gelap');
  });

  test('migrasi noir -> gelap ditulis balik ke prefs', () async {
    SharedPreferences.setMockInitialValues({'app_theme_choice': 'noir'});
    final p = await SharedPreferences.getInstance();
    await loadAppSettings(p);
    expect(themeChoice.value, 'gelap');
    expect(p.getString('app_theme_choice'), 'gelap');
  });

  test('jam batas tema fail-safe + persist', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await loadAppSettings(p);
    expect(themeDayStart.value, 6);
    expect(themeNightStart.value, 18);
    await setThemeDayStart(7);
    expect(themeDayStart.value, 7);
    await setThemeNightStart(19);
    expect(themeNightStart.value, 19);
    await setThemeDayStart(99);
    expect(themeDayStart.value, 23);
    await setThemeNightStart(-5);
    expect(themeNightStart.value, 0);
    SharedPreferences.setMockInitialValues({
      'app_theme_day_start': 5,
      'app_theme_night_start': 20,
    });
    final p2 = await SharedPreferences.getInstance();
    await loadAppSettings(p2);
    expect(themeDayStart.value, 5);
    expect(themeNightStart.value, 20);
  });

  test('resolusi tema efektif', () {
    String r(String c, int h, int ds, int ns) => resolveEffectiveTheme(
          choice: c,
          hour: h,
          dayStart: ds,
          nightStart: ns,
        );
    expect(r('terang', 3, 6, 18), 'terang');
    expect(r('gelap', 12, 6, 18), 'gelap');
    expect(r('otomatis', 6, 6, 18), 'terang');
    expect(r('otomatis', 17, 6, 18), 'terang');
    expect(r('otomatis', 18, 6, 18), 'gelap');
    expect(r('otomatis', 5, 6, 18), 'gelap');
    // Rentang melintasi tengah malam: terang 20:00 s/d 06:00.
    expect(r('otomatis', 22, 20, 6), 'terang');
    expect(r('otomatis', 3, 20, 6), 'terang');
    expect(r('otomatis', 12, 20, 6), 'gelap');
    // Batas sama = terang seharian.
    expect(r('otomatis', 2, 6, 6), 'terang');
  });
}
