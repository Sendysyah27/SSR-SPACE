import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/receipt_result_sheet.dart';

Widget _wrap(ReceiptData data) => MaterialApp(
  home: Scaffold(body: ReceiptResultSheet(data: data, onShowRaw: () {})),
);

void main() {
  testWidgets('merchant + item + total tampil', (t) async {
    await t.pumpWidget(
      _wrap(
        const ReceiptData(
          merchant: 'TOKO KOPI',
          items: ['Kopi 25000', 'Roti 15000'],
          amount: 40000,
          confident: true,
        ),
      ),
    );
    expect(find.text('TOKO KOPI'), findsOneWidget);
    expect(find.textContaining('Kopi'), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text(tr('rcp_check')), findsNothing);
  });

  testWidgets('tak-yakin tampil peringatan', (t) async {
    await t.pumpWidget(
      _wrap(
        const ReceiptData(
          items: ['Barang 10000'],
          amount: 10000,
          confident: false,
        ),
      ),
    );
    expect(find.text(tr('rcp_check')), findsOneWidget);
    expect(find.text(tr('rcp_raw_title')), findsOneWidget);
  });
}
