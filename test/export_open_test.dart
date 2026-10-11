import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/export_open.dart';

void main() {
  test('payload bagi -> path, lain -> null', () {
    expect(exportOpenPath('share_file:/a/b.xlsx'), '/a/b.xlsx');
    expect(exportOpenPath('share_file:'), isNull);
    expect(exportOpenPath(''), isNull);
    expect(exportOpenPath(null), isNull);
    expect(exportOpenPath('lain:/a'), isNull);
  });

  test('mime dari ekstensi', () {
    expect(
      exportOpenMime('/d/laporan.xlsx'),
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    expect(exportOpenMime('/d/laporan.pdf'), 'application/pdf');
    expect(exportOpenMime('/d/laporan.CSV'), isNull);
    expect(exportOpenMime(''), isNull);
  });
}
