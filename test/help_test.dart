import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/utils/strings.dart';

/// Kunci konten HelpScreen: judul + 6 tutorial + 6 FAQ, semua ID+EN.
const _hpKeys = <String>[
  'hp_title',
  'hp_guide',
  'hp_faq',
  'hp_start_t',
  'hp_start_b',
  'hp_record_t',
  'hp_record_b',
  'hp_track_t',
  'hp_track_b',
  'hp_budget_t',
  'hp_budget_b',
  'hp_report_t',
  'hp_report_b',
  'hp_pin_t',
  'hp_pin_b',
  'hp_q1',
  'hp_a1',
  'hp_q2',
  'hp_a2',
  'hp_q3',
  'hp_a3',
  'hp_q4',
  'hp_a4',
  'hp_q5',
  'hp_a5',
  'hp_q6',
  'hp_a6',
];

void main() {
  test('semua kunci bantuan ada ID+EN dan tak kosong', () {
    expect(_hpKeys.length, 27);
    for (final loc in ['id', 'en']) {
      localeCode.value = loc;
      for (final k in _hpKeys) {
        final v = tr(k);
        expect(v == k, false, reason: '$k hilang di $loc');
        expect(v.trim().isNotEmpty, true, reason: '$k kosong di $loc');
      }
    }
    localeCode.value = 'id';
  });

  test('terjemahan EN beda dari ID (bukan fallback)', () {
    localeCode.value = 'id';
    final ids = {for (final k in _hpKeys) k: tr(k)};
    localeCode.value = 'en';
    for (final k in _hpKeys) {
      expect(tr(k) == ids[k], false, reason: '$k EN sama dengan ID');
    }
    localeCode.value = 'id';
  });
}
