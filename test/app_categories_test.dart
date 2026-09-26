import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/app_categories.dart';

void main() {
  test('bawaan tepat 10', () {
    expect(kDefaultCategories.length, 10);
    expect(kDefaultCategories.first, 'Makanan');
    expect(kDefaultCategories.last, 'Lainnya');
  });

  test('sanitize trim, buang kosong, dedupe', () {
    expect(sanitizeCategories([' Makanan ', '', 'MAKANAN', '  ', 'Jajan']), [
      'Makanan',
      'Jajan',
    ]);
  });

  test('sanitize kosong kembali ke bawaan', () {
    expect(sanitizeCategories([]), kDefaultCategories);
    expect(sanitizeCategories(['', '   ']), kDefaultCategories);
  });

  test('sanitize batasi 20', () {
    final raw = List.generate(25, (i) => 'K$i');
    final out = sanitizeCategories(raw);
    expect(out.length, 20);
    expect(out.first, 'K0');
  });
}
