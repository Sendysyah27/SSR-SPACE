import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/game_level.dart';

void main() {
  test('batas level + mentok', () {
    expect(levelFor(0), 1);
    expect(levelFor(199), 1);
    expect(levelFor(200), 2);
    expect(levelFor(20000), 7);
    expect(xpToNext(20000), 0);
    expect(levelProgress(20000), 1);
  });

  test('progres dan sisa', () {
    expect(xpToNext(100), 100);
    expect(levelProgress(100), closeTo(0.5, 1e-9));
  });
}
