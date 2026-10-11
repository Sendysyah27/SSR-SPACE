import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/xlsx_layout.dart';

void main() {
  test('lebar = terpanjang + pad, jepit min-maks', () {
    expect(xlsxFitWidth(['ab', 'abcd']), 10);
    expect(xlsxFitWidth(['ab', 'abcd'], min: 4), 6);
    expect(xlsxFitWidth(['x']), 10);
    expect(xlsxFitWidth([for (var i = 0; i < 60; i++) 'y'].join()), 50);
  });

  test('header ikut diukur', () {
    expect(xlsxFitWidth(['ke_dompet', 'BCA']), 11);
  });
}
