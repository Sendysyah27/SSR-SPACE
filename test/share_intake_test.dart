import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/share_intake.dart';

void main() {
  group('pickFirstImage', () {
    test('kosong -> (null, false)', () {
      final r = pickFirstImage([]);
      expect(r.first, isNull);
      expect(r.hadMore, isFalse);
    });

    test('satu -> (itu, false)', () {
      final r = pickFirstImage(['/a.jpg']);
      expect(r.first, '/a.jpg');
      expect(r.hadMore, isFalse);
    });

    test('tiga -> (pertama, true)', () {
      final r = pickFirstImage(['/a.jpg', '/b.png', '/c.jpg']);
      expect(r.first, '/a.jpg');
      expect(r.hadMore, isTrue);
    });
  });
}
