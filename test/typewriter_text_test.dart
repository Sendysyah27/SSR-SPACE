import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/widgets/typewriter_text.dart';

void main() {
  group('typewriterShown murni', () {
    test('awal 0, akhir penuh, monoton naik', () {
      expect(typewriterShown(100, 0), 0);
      expect(typewriterShown(100, 99999), 100);
      var prev = 0;
      for (var ms = 0; ms <= 3000; ms += 100) {
        final n = typewriterShown(100, ms);
        expect(n >= prev, isTrue);
        expect(n <= 100, isTrue);
        prev = n;
      }
    });

    test('teks panjang selesai <= 2,8 detik (adaptif)', () {
      expect(typewriterDurationMs(1000), 2800);
      expect(typewriterShown(1000, 2800), 1000);
    });

    test('teks kosong aman', () {
      expect(typewriterShown(0, 100), 0);
      expect(typewriterDurationMs(0), 0);
    });
  });

  group('TypewriterText widget', () {
    testWidgets('teks muncul progresif lalu utuh', (tester) async {
      const full = 'Halo, ini jawaban asisten yang cukup panjang.';
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: TypewriterText(text: full)),
      ));
      // Awal: belum utuh.
      expect(find.text(full), findsNothing);
      // Jalan ~3 detik (durasi maks 2,8 dtk) -> utuh.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(full), findsOneWidget);
    });

    testWidgets('ketuk -> langsung utuh', (tester) async {
      const full = 'Jawaban panjang yang diketuk di tengah animasi.';
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: TypewriterText(text: full)),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(full), findsNothing);
      await tester.tap(find.byType(TypewriterText));
      await tester.pump();
      expect(find.text(full), findsOneWidget);
    });

    testWidgets('dispose di tengah animasi tidak menyisakan timer',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: TypewriterText(text: 'Teks yang belum selesai.')),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      // Timer.periodic yang bocor akan menggagalkan test ini di akhir.
    });
  });
}
