import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/receipt_scan_service.dart';

void main() {
  test('piksel putih 2x2 -> Y235 VU128', () {
    final white = Uint8List.fromList(List.filled(2 * 2 * 4, 255));
    final out = rgbaToNv21(white, 2, 2);
    expect(out.length, 6);
    expect(out.sublist(0, 4), [235, 235, 235, 235]);
    expect(out.sublist(4), [128, 128]);
  });

  test('blok 2x2 hitam -> Y16 dan VU128', () {
    final black = Uint8List.fromList(List.filled(2 * 2 * 4, 0));
    for (var i = 3; i < black.length; i += 4) {
      black[i] = 255;
    }
    final out = rgbaToNv21(black, 2, 2);
    expect(out.length, 2 * 2 + 2);
    expect(out.sublist(0, 4), [16, 16, 16, 16]);
    expect(out.sublist(4), [128, 128]);
  });

  test('panjang NV21 pas untuk genap', () {
    final rgba = Uint8List.fromList(List.filled(160 * 100 * 4, 128));
    final out = rgbaToNv21(rgba, 160, 100);
    expect(out.length, 160 * 100 + 160 * 100 ~/ 2);
  });
}
