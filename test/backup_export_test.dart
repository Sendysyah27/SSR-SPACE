import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/core/saas/backup_export.dart';

void main() {
  test('nama file backup', () {
    expect(backupFileNames(), [
      'dompet-ssr-space.csv',
      'transaksi-ssr-space.csv',
      'budget-ssr-space.csv',
    ]);
  });

  test('dompet CSV: header + baris', () {
    final csv = walletsCsv([
      {'id': 'w1', 'name': 'DANA', 'type': 'ewallet'},
    ]);
    final lines = LineSplitter().split(csv).toList();
    expect(lines[0], 'id,nama,tipe');
    expect(lines[1], 'w1,DANA,ewallet');
    expect(lines.length, 2);
  });

  test('transaksi CSV: header lengkap + escaping koma/kutip', () {
    final csv = transactionsCsv([
      {
        'id': 't1',
        'code': 'TX-000001',
        'date': '2026-09-25',
        'type': 'out',
        'amount': 15000,
        'category': 'Makan',
        'note': 'Nasi, "komplit"',
        'wallet_id': 'w1',
        'to_wallet_id': null,
        'source_package': 'id.dana',
      },
    ]);
    final lines = LineSplitter().split(csv).toList();
    expect(
      lines[0],
      'id,kode,tanggal,jenis,nominal,kategori,catatan,dompet_id,ke_dompet_id,sumber_aplikasi',
    );
    expect(lines[1], contains('"Nasi, ""komplit"""'));
    expect(lines[1], contains('15000'));
    expect(lines[1], contains('id.dana'));
    expect(lines[1], contains('TX-000001'));
  });

  test('budget CSV: header + limit', () {
    final csv = budgetsCsv([
      {'category': 'Makan', 'month': '2026-09', 'limit_amount': 800000},
    ]);
    final lines = LineSplitter().split(csv).toList();
    expect(lines[0], 'kategori,bulan,limit');
    expect(lines[1], 'Makan,2026-09,800000');
  });

  test('baris kosong = hanya header', () {
    expect(
      LineSplitter().split(walletsCsv(const [])).toList(),
      ['id,nama,tipe'],
    );
  });
}
