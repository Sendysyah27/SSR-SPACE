import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/utils/strings.dart';

void main() {
  test('setiap kunci punya id + en tak kosong', () {
    final bad = <String>[];
    stringTable.forEach((key, langs) {
      if ((langs['id'] ?? '').isEmpty || (langs['en'] ?? '').isEmpty) {
        bad.add(key);
      }
    });
    expect(bad, isEmpty, reason: 'kunci jomplang: $bad');
  });

  test('kunci baru batch 28-29 lengkap dua bahasa', () {
    for (final k in [
      'txf_search',
      'txf_filter',
      'txf_del_body',
      'sv30_title',
      'sv30_mile',
      'sv30_remind_b',
      'b_save30_t',
      'b_save30_d',
    ]) {
      expect(stringTable.containsKey(k), isTrue, reason: k);
    }
  });
}
