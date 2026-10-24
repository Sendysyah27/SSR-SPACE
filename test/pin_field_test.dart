import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/widgets/pin_field.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/widgets/pin_pad.dart';

void main() {
  // Desain batch 287 tahap 2d: indikator = titik lingkaran 13px
  // (terisi = navy penuh, kosong = transparan) — tidak ada lagi teks.
  Finder pinDots() => find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.width == 13 &&
            (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      );
  Finder pinDotsFilled() => find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.width == 13 &&
            (w.decoration as BoxDecoration?)?.shape == BoxShape.circle &&
            (w.decoration as BoxDecoration?)?.color == DribTokens.navy,
      );

  testWidgets('PinField gambar titik dari controller, onCompleted sekali', (
    tester,
  ) async {
    final c = TextEditingController();
    var fired = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinField(controller: c, length: 6, onCompleted: (_) => fired++),
        ),
      ),
    );

    expect(pinDots(), findsNWidgets(6), reason: 'PIN 6 digit = 6 titik');
    expect(pinDotsFilled(), findsNothing);

    c.text = '123';
    await tester.pump();
    expect(pinDotsFilled(), findsNWidgets(3));

    c.text = '123456';
    await tester.pump();
    expect(pinDotsFilled(), findsNWidgets(6));
    expect(fired, 1);

    c.text = '123456';
    await tester.pump();
    expect(fired, 1, reason: 'guard anti-tembak-ganda');

    c.text = '';
    await tester.pump();
    expect(pinDotsFilled(), findsNothing);
    c.text = '123456';
    await tester.pump();
    expect(fired, 2, reason: 'guard reset setelah panjang berkurang');

    c.dispose();
  });

  testWidgets('PinField tampilkan error', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinField(controller: c, length: 6, error: 'PIN salah.'),
        ),
      ),
    );
    expect(find.text('PIN salah.'), findsOneWidget);
    c.dispose();
  });

  testWidgets('PinPad ketik mengisi controller dan berhenti di maxLen', (
    tester,
  ) async {
    final c = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PinPad(controller: c, length: 6)),
      ),
    );

    for (final d in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    expect(c.text, '123456');

    await tester.tap(find.text('7'));
    await tester.pump();
    expect(c.text, '123456', reason: 'PIN dibatasi 6 digit');

    c.dispose();
  });
}
