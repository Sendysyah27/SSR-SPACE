import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/widgets/category_chips.dart';
import 'package:ssr_space/widgets/status_chip.dart';

void main() {
  testWidgets('ketuk chip mengisi controller', (t) async {
    final c = TextEditingController();
    await t.pumpWidget(
      MaterialApp(home: Scaffold(body: CategoryChips(controller: c))),
    );
    await t.tap(find.text('Makanan'));
    await t.pump();
    expect(c.text, 'Makanan');
  });

  testWidgets('chip terpilih tampil aksen', (t) async {
    final c = TextEditingController(text: 'Makanan');
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryChips(controller: c, selected: 'Makanan'),
        ),
      ),
    );
    final chip = t.widget<StatusChip>(
      find.widgetWithText(StatusChip, 'Makanan'),
    );
    expect(chip.tone, StatusTone.accent);
    final other = t.widget<StatusChip>(
      find.widgetWithText(StatusChip, 'Belanja'),
    );
    expect(other.tone, StatusTone.neutral);
  });
}
