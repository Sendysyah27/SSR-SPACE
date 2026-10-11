import 'package:flutter_test/flutter_test.dart';
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
}
