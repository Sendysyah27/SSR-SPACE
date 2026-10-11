import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/xlsx_layout.dart';

void main() {
  test('lebar = terpanjang + pad, jepit min-maks', () {
    expect(xlsxFitWidth(['ab', 'abcd']), 10);
    expect(xlsxFitWidth(['ab', 'abcd'], min: 4), 6);
    expect(xlsxFitWidth(['x']), 10);
    expect(xlsxFitWidth([List.filled(60, 'y').join()]), 50);
  });

  test('header ikut diukur', () {
    expect(xlsxFitWidth(['ke_dompet', 'BCA']), 11);
  });

  test('tanggal full Indonesia', () {
    expect(idFullDate(DateTime(2026, 10, 11)), '11 Okt 2026');
    expect(idFullDate(DateTime(2026, 1, 5)), '5 Jan 2026');
    expect(idFullDate(DateTime(2026, 12, 31)), '31 Des 2026');
  });
}
