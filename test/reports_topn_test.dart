import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/reports_topn.dart';

Map<String, double> cats(int n, {double base = 1000}) => {
      for (var i = 0; i < n; i++)
        'K${(i + 1).toString().padLeft(2, '0')}': base + (n - i),
    };

void main() {
  test('12 kategori: Top-8 plus Others 4, jumlah Others tepat', () {
    final r = top8PlusOthers(cats(12));
    expect(r.top.length, 8);
    expect(r.others.length, 4);
    expect(r.top.first.name, 'K01');
    final all = cats(12);
    final totalAll = all.values.fold<double>(0, (s, v) => s + v);
    final shown = r.top.fold<double>(0, (s, c) => s + c.total) + r.othersTotal;
    expect(shown, totalAll);
  });

  test('8 atau kurang: tanpa Others', () {
    expect(top8PlusOthers(cats(8)).others, isEmpty);
    expect(top8PlusOthers(cats(3)).top.length, 3);
  });

  test('seri di batas 8: abjad stabil', () {
    final r = top8PlusOthers({
      for (var i = 0; i < 10; i++) 'K${String.fromCharCode(65 + i)}': 100,
    });
    expect(r.top.map((c) => c.name).toList(), [
      'KA',
      'KB',
      'KC',
      'KD',
      'KE',
      'KF',
      'KG',
      'KH',
    ]);
    expect(r.others.map((c) => c.name).toList(), ['KI', 'KJ']);
  });

  test('toggle mati: semua di top', () {
    final r = top8PlusOthers(cats(12), enabled: false);
    expect(r.top.length, 12);
    expect(r.others, isEmpty);
  });

  test('prefs rusak fallback baku, asing dibuang, hilang ditambah', () {
    expect(sanitizeSectionOrder(null), defaultSectionOrder);
    expect(sanitizeSectionOrder([]), defaultSectionOrder);
    expect(sanitizeSectionOrder(['asing', 'x']), defaultSectionOrder);
    expect(
      sanitizeSectionOrder(['list', 'summary', 'list', 'asing']),
      ['list', 'summary', 'recap'],
    );
    expect(sanitizeSectionOrder(['recap']), ['recap', 'summary', 'list']);
  });
}
