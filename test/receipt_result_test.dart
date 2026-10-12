import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/receipt_result_sheet.dart';

Widget _wrap(ReceiptData data, List<MirrorLine> mirror) => MaterialApp(
  home: Scaffold(
    body: ReceiptResultSheet(data: data, mirror: mirror, onShowRaw: () {}),
  ),
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
        const [
          MirrorLine('TOKO KOPI', centered: true, bold: true),
          MirrorLine('Kopi', amount: 25000),
          MirrorLine('Roti', amount: 15000),
          MirrorLine('TOTAL :', amount: 40000, bold: true),
        ],
      ),
    );
    expect(find.text('TOKO KOPI'), findsOneWidget);
    expect(find.textContaining('Kopi'), findsOneWidget);
    expect(find.text('TOTAL :'), findsOneWidget);
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
        const [
          MirrorLine('Barang', amount: 10000),
        ],
      ),
    );
    expect(find.text(tr('rcp_check')), findsOneWidget);
    expect(find.text(tr('rcp_raw_title')), findsOneWidget);
  });
}
