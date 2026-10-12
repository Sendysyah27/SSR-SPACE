import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/receipt_layout.dart';

OcrBox b(String t, int l, int tp, int r, int bt) =>
    OcrBox(t, l, tp, r, bt);

void main() {
  test('sebaris digabung urut X', () {
    final out = spatialLines([
      b('57500', 300, 100, 380, 120),
      b('AMANDA BROWNIES ORI', 10, 102, 250, 121),
    ]);
    expect(out, ['AMANDA BROWNIES ORI 57500']);
  });

  test('urut Y walau input acak', () {
    final out = spatialLines([
      b('TOTAL : 69000', 10, 200, 250, 220),
      b('KOPI 19000', 10, 100, 250, 120),
    ]);
    expect(out, ['KOPI 19000', 'TOTAL : 69000']);
  });

  test('toleransi goyang 2px sebaris', () {
    final out = spatialLines([
      b('Kopi', 10, 100, 100, 120),
      b('19000', 300, 102, 380, 122),
    ]);
    expect(out, ['Kopi 19000']);
  });

  test('baris beda tetap pisah', () {
    final out = spatialLines([
      b('A', 10, 100, 50, 120),
      b('B', 10, 150, 50, 170),
    ]);
    expect(out, ['A', 'B']);
  });

  test('kosong dibuang', () {
    expect(spatialLines([b('  ', 0, 0, 1, 1)]), isEmpty);
    expect(spatialLines([]), isEmpty);
  });
}
