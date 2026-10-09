import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/async_guard.dart';

/// Simulasi tiap service throw: guard WAJIB kembalikan fallback,
/// tak pernah lempar ke pemanggil (ini yang dulu jadi "has stopped").
void main() {
  group('guardAsync', () {
    test('sukses → nilai asli', () async {
      expect(await guardAsync(() async => 42, 0), 42);
    });
    test('StateError async → fallback', () async {
      Future<int> boom() async => throw StateError('jaringan putus');
      expect(await guardAsync(boom, -1), -1);
    });
    test('throw sync di dalam fn → fallback', () async {
      Future<String> boom() => throw 'string-throw';
      expect(await guardAsync(boom, 'aman'), 'aman');
    });
    test('list tx gagal → list kosong', () async {
      Future<List<int>> boom() async => throw Exception('RLS');
      expect(await guardAsync(boom, <int>[]), isEmpty);
    });
    test('prefs gagal → fallback string', () async {
      Future<String> boom() async => throw Exception('prefs korup');
      expect(await guardAsync(boom, '-'), '-');
    });
    test('TypeError (cast data aneh) → fallback', () async {
      Future<double> boom() async => throw TypeError();
      expect(await guardAsync(boom, 0.0), 0.0);
    });
  });

  group('runGuarded', () {
    test('sukses jalan, gagal diam', () async {
      var n = 0;
      await runGuarded(() async => n++);
      expect(n, 1);
      await runGuarded(() async => throw Exception('plugin'));
      expect(n, 1);
    });
  });
}
