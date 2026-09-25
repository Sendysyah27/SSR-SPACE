import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/core/saas/error_reporter.dart';

void main() {
  setUp(ErrorReporter.reset);

  test('signature sama dalam 60 menit ditolak, lewat itu boleh lagi', () {
    final t0 = DateTime.now();
    expect(ErrorReporter.admit('notif|boom', t0), isTrue);
    expect(
      ErrorReporter.admit('notif|boom', t0.add(const Duration(minutes: 59))),
      isFalse,
    );
    expect(
      ErrorReporter.admit('notif|boom', t0.add(const Duration(minutes: 61))),
      isTrue,
    );
  });

  test('signature berbeda tidak saling menahan', () {
    final t0 = DateTime.now();
    expect(ErrorReporter.admit('a|boom', t0), isTrue);
    expect(ErrorReporter.admit('b|boom', t0), isTrue);
  });

  test('maks 20 event per jam, reset di jam berikutnya', () {
    final t0 = DateTime.now();
    for (var i = 0; i < ErrorReporter.maxPerHour; i++) {
      expect(ErrorReporter.admit('sig$i', t0), isTrue);
    }
    expect(ErrorReporter.admit('sig-lewat', t0), isFalse);
    expect(
      ErrorReporter.admit('sig-aku-jam-2', t0.add(const Duration(hours: 1))),
      isTrue,
    );
  });

  test('payload terpotong, kunci persis, tanpa field terlarang', () {
    final p = ErrorReporter.payload(
      message: 'x' * 600,
      stack: 'y' * 5000,
      context: 'notif_pipeline',
    );
    expect((p['message'] as String).length, 500);
    expect((p['stack'] as String).length, 4000);
    expect(p['context'], 'notif_pipeline');
    expect(p['app_version'], isNotEmpty);
    expect(
      p.keys.toSet(),
      {'message', 'stack', 'context', 'app_version'},
      reason: 'payload monitoring tidak boleh membawa kolom lain',
    );
  });

  test('payload stack null tetap valid', () {
    final p = ErrorReporter.payload(message: 'boom');
    expect(p['stack'], isNull);
    expect(p['context'], isNull);
  });
}
