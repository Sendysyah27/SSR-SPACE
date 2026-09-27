import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/utils/datetime.dart';

void main() {
  test('txWhenLabel gabung tanggal dan jam', () {
    final iso = DateTime(2026, 9, 26, 12, 4).toIso8601String();
    expect(txWhenLabel('2026-09-26', iso), '26 Sep 2026 · 12:04');
  });

  test('txWhenLabel tanggal saja bila jam kosong', () {
    expect(txWhenLabel('2026-09-26', null), '26 Sep 2026');
    expect(txWhenLabel('2026-09-26', ''), '26 Sep 2026');
    expect(txWhenLabel('2026-09-26', 'bukan-tanggal'), '26 Sep 2026');
  });

  test('txWhenLabel jam saja bila tanggal kosong', () {
    final iso = DateTime(2026, 9, 26, 8, 30).toIso8601String();
    expect(txWhenLabel(null, iso), '08:30');
    expect(txWhenLabel('bad', iso), '08:30');
  });

  test('txWhenLabel kosong bila tak ada data', () {
    expect(txWhenLabel(null, null), '');
    expect(txWhenLabel('bad', ''), '');
  });
}
