import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/report_pdf.dart';

SaasTransaction _tx(String type, double amount, {String? category}) {
  return SaasTransaction(
    id: '$type-$amount',
    orgId: 'org',
    type: type,
    amount: amount,
    category: category,
    date: '2026-09-01',
    note: 'uji',
  );
}

void main() {
  test('PDF kosong tetap jadi dokumen valid', () async {
    final bytes = await buildReportPdf(
      orgName: 'Keluarga',
      monthLabel: 'September 2026',
      items: const [],
    );
    expect(bytes.length, greaterThan(500));
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });

  test('PDF berisi transaksi tetap valid', () async {
    final bytes = await buildReportPdf(
      orgName: 'Keluarga',
      monthLabel: 'September 2026',
      items: [
        _tx('in', 100000, category: 'Gaji'),
        _tx('out', 25000, category: 'Makan'),
        _tx('out', 10000),
      ],
    );
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });
}
