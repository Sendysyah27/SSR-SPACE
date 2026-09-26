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
}
