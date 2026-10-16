import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/today_widget.dart';
import 'package:ssr_space/services/widget_snapshot.dart';

void main() {
  test('format dan parse balik', () {
    final raw = formatSnapshot(
      date: '2026-09-27',
      text: 'Hari ini · Rp10.000',
      masked: false,
    );
    final s = parseSnapshot(raw);
    expect(s, isNotNull);
    expect(s!.date, '2026-09-27');
    expect(s.text, 'Hari ini · Rp10.000');
    expect(s.masked, false);
  });

  test('mask menyamarkan angka widget', () {
    final raw = formatSnapshot(
      date: '2026-09-27',
      text: 'Rp ••••••',
      masked: true,
    );
    expect(parseSnapshot(raw)!.masked, true);
  });

  test('snapshot basi tetap berlabel tanggal benar', () {
    final raw = formatSnapshot(date: '2026-09-20', text: 'x', masked: false);
    expect(parseSnapshot(raw)!.date, '2026-09-20');
  });

  test('rusak atau hilang -> null (provider tampilkan ajakan)', () {
    expect(parseSnapshot(null), isNull);
    expect(parseSnapshot(''), isNull);
    expect(parseSnapshot('bukan json'), isNull);
    expect(parseSnapshot('{"date":"2026-09-27"}'), isNull);
  });

  test('baris kedua round-trip', () {
    final raw = formatSnapshot(
      date: '2026-10-11',
      text: 'Keluar Rp20.000',
      text2: 'Sisa budget Rp80.000',
      masked: false,
    );
    final s = parseSnapshot(raw)!;
    expect(s.text2, 'Sisa budget Rp80.000');
  });

  test('format lama tanpa baris kedua tetap terbaca', () {
    final raw = formatSnapshot(date: '2026-10-11', text: 'x', masked: false);
    expect(parseSnapshot(raw)!.text2, '');
  });

  test('sisa budget = jumlah limit kurang belanja', () {
    expect(
      widgetBudgetLeft({'Makan': 100000, 'Belanja': 50000}, {'Makan': 30000}),
      120000,
    );
    expect(widgetBudgetLeft({}, {}), 0);
    expect(widgetBudgetLeft({'Makan': 100000}, {'Makan': 150000}), -50000);
  });

  test('kontrak provider: 4 kunci selalu ada (fix widget FC)', () {
    final raw = formatSnapshot(date: '2026-10-11', text: '', masked: false);
    expect(raw, contains('"date"'));
    expect(raw, contains('"text"'));
    expect(raw, contains('"text2"'));
    expect(raw, contains('"masked"'));
    // Provider baca via optString/optInt: tak pernah throw untuk format ini.
    expect(parseSnapshot(raw)!.text2, '');
  });

  group('varian budget + saldo (fase 2 widget)', () {
    test('kontrak kunci: 3 key distinct, format identik', () {
      expect(widgetBudgetSnapshotKey, 'widget_snapshot_budget');
      expect(widgetBalanceSnapshotKey, 'widget_snapshot_balance');
      expect(widgetBudgetSnapshotKey, isNot('widget_snapshot'));
      expect(widgetBalanceSnapshotKey, isNot('widget_snapshot'));
      expect(widgetBalanceSnapshotKey, isNot(widgetBudgetSnapshotKey));
    });

    test('varian budget round-trip via format+parse', () {
      final raw = formatSnapshot(
        date: '2026-10-17',
        text: 'Sisa budget Rp80.000',
        text2: 'Aman sampai akhir bulan',
        masked: false,
      );
      final s = parseSnapshot(raw)!;
      expect(s.date, '2026-10-17');
      expect(s.text, 'Sisa budget Rp80.000');
      expect(s.text2, 'Aman sampai akhir bulan');
      expect(s.masked, false);
    });

    test('varian saldo round-trip via format+parse', () {
      final raw = formatSnapshot(
        date: '2026-10-17',
        text: 'Total aset Rp1.250.000',
        text2: '3 dompet · 2026-10-17',
        masked: false,
      );
      final s = parseSnapshot(raw)!;
      expect(s.text, 'Total aset Rp1.250.000');
      expect(s.text2, '3 dompet · 2026-10-17');
    });

    test('varian tanpa text2 → text2 kosong (kompatibel lama)', () {
      final raw = formatSnapshot(
        date: '2026-10-17',
        text: 'Sisa budget Rp0',
        masked: false,
      );
      expect(parseSnapshot(raw)!.text2, '');
    });

    test('varian rusak → null (provider tampilkan ajakan)', () {
      expect(parseSnapshot('{"date":"2026-10-17","text":1}'), isNull);
      expect(parseSnapshot('{"text":"x","text2":"y","masked":0}'), isNull);
    });

    test('sisa negatif (jebol) ditulis apa adanya', () {
      expect(
        widgetBudgetLeft({'Makan': 100000}, {'Makan': 150000}),
        -50000,
      );
    });

    test('lampu: jebol atau minus → danger, selain itu safe', () {
      expect(widgetBudgetLamp(left: 120000, anyOver: false), 'safe');
      expect(widgetBudgetLamp(left: 0, anyOver: false), 'safe');
      expect(widgetBudgetLamp(left: -50000, anyOver: false), 'danger');
      expect(widgetBudgetLamp(left: 10000, anyOver: true), 'danger');
    });

    test('toggle mati → refreshTodayWidget hapus ketiga kunci', () async {
      SharedPreferences.setMockInitialValues({
        'widget_snapshot': 'x',
        'widget_snapshot_budget': 'y',
        'widget_snapshot_balance': 'z',
      });
      widgetToday.value = false;
      await refreshTodayWidget(date: '2026-10-17', text: 't');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('widget_snapshot'), isNull);
      expect(prefs.getString('widget_snapshot_budget'), isNull);
      expect(prefs.getString('widget_snapshot_balance'), isNull);
      widgetToday.value = true;
    });

    test('toggle mati → clearTodaySnapshot hapus ketiga kunci', () async {
      SharedPreferences.setMockInitialValues({
        'widget_snapshot': 'x',
        'widget_snapshot_budget': 'y',
        'widget_snapshot_balance': 'z',
      });
      await clearTodaySnapshot();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('widget_snapshot'), isNull);
      expect(prefs.getString('widget_snapshot_budget'), isNull);
      expect(prefs.getString('widget_snapshot_balance'), isNull);
    });

    test('penulis varian no-op tanpa toggle/org (tanpa network)', () async {
      SharedPreferences.setMockInitialValues({});
      widgetToday.value = false;
      await refreshWidgetBudgetSnapshot('org-x');
      await refreshWidgetBalanceSnapshot('org-x');
      widgetToday.value = true;
      await refreshWidgetBudgetSnapshot('');
      await refreshWidgetBalanceSnapshot('');
      widgetToday.value = false;
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('widget_snapshot_budget'), isNull);
      expect(prefs.getString('widget_snapshot_balance'), isNull);
    });
  });
}
