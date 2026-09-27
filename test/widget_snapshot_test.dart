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
}
