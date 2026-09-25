import 'package:csv/csv.dart';

/// Nama file cadangan, urutan = [dompet, transaksi, budget].
List<String> backupFileNames() => const [
      'dompet-ssr-space.csv',
      'transaksi-ssr-space.csv',
      'budget-ssr-space.csv',
    ];

String walletsCsv(List<Map<String, dynamic>> rows) {
  final data = <List<dynamic>>[
    ['id', 'nama', 'tipe'],
    for (final r in rows)
      [
        (r['id'] ?? '').toString(),
        (r['name'] ?? '').toString(),
        (r['type'] ?? '').toString(),
      ],
  ];
  return const ListToCsvConverter().convert(data);
}

String transactionsCsv(List<Map<String, dynamic>> rows) {
  final data = <List<dynamic>>[
    [
      'id',
      'kode',
      'tanggal',
      'jenis',
      'nominal',
      'kategori',
      'catatan',
      'dompet_id',
      'ke_dompet_id',
      'sumber_aplikasi',
    ],
    for (final r in rows)
      [
        (r['id'] ?? '').toString(),
        (r['code'] ?? '').toString(),
        (r['date'] ?? '').toString(),
        (r['type'] ?? '').toString(),
        (r['amount'] ?? '').toString(),
        (r['category'] ?? '').toString(),
        (r['note'] ?? '').toString(),
        (r['wallet_id'] ?? '').toString(),
        (r['to_wallet_id'] ?? '').toString(),
        (r['source_package'] ?? '').toString(),
      ],
  ];
  return const ListToCsvConverter().convert(data);
}

String budgetsCsv(List<Map<String, dynamic>> rows) {
  final data = <List<dynamic>>[
    ['kategori', 'bulan', 'limit'],
    for (final r in rows)
      [
        (r['category'] ?? '').toString(),
        (r['month'] ?? '').toString(),
        (r['limit_amount'] ?? '').toString(),
      ],
  ];
  return const ListToCsvConverter().convert(data);
}
