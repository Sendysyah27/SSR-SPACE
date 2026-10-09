import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/app_settings.dart';

void main() {
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
    await loadAppSettings(p);
    expect(numberFormat.value, 'id');
    expect(defaultWalletId.value, '');
    expect(weekStart.value, 1);
    expect(lockTimeoutMinutes.value, 5);
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
    });
    final p2 = await SharedPreferences.getInstance();
    await loadAppSettings(p2);
    expect(numberFormat.value, 'us');
    expect(defaultWalletId.value, 'w9');
    expect(weekStart.value, 7);
    expect(lockTimeoutMinutes.value, 30);
  });

  test('theme choice fail-safe + persist', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await loadAppSettings(p);
    expect(themeChoice.value, 'otomatis');
    await setThemeChoice('noir');
    expect(themeChoice.value, 'noir');
    await setThemeChoice('invalid');
    expect(themeChoice.value, 'noir');
    await setThemeChoice('otomatis');
    expect(themeChoice.value, 'otomatis');
    await setThemeChoice('invalid');
    expect(themeChoice.value, 'otomatis');
    SharedPreferences.setMockInitialValues({'app_theme_choice': 'noir'});
    final p2 = await SharedPreferences.getInstance();
    await loadAppSettings(p2);
    expect(themeChoice.value, 'noir');
  });
}
