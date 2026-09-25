import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/transfer_detect.dart';

SaasTransaction _tx({
  required String id,
  required String type,
  required double amount,
  String? wallet,
  String? toWallet,
  String? at,
}) {
  return SaasTransaction(
    id: id,
    orgId: 'org',
    type: type,
    amount: amount,
    walletId: wallet,
    toWalletId: toWallet,
    createdAt: at,
  );
}

void main() {
  test('pasangan out+in nominal sama <=10 menit terdeteksi', () {
    final items = [
      _tx(
        id: 'o1',
        type: 'out',
        amount: 50000,
        wallet: 'wa',
        at: '2026-09-26T12:01:00+00:00',
      ),
      _tx(
        id: 'i1',
        type: 'in',
        amount: 50000,
        wallet: 'wb',
        at: '2026-09-26T12:04:00+00:00',
      ),
    ];
    final pairs = detectTransferPairs(items);
    expect(pairs.length, 1);
    expect(pairs.first.outTx.id, 'o1');
    expect(pairs.first.inTx.id, 'i1');
  });

  test('dompet sama / beda nominal / lewat jendela ditolak', () {
    final items = [
      _tx(
        id: 'o1',
        type: 'out',
        amount: 50000,
        wallet: 'wa',
        at: '2026-09-26T12:01:00+00:00',
      ),
      _tx(
        id: 'i-same',
        type: 'in',
        amount: 50000,
        wallet: 'wa',
        at: '2026-09-26T12:02:00+00:00',
      ),
      _tx(
        id: 'i-diff',
        type: 'in',
        amount: 60000,
        wallet: 'wb',
        at: '2026-09-26T12:02:00+00:00',
      ),
      _tx(
        id: 'i-late',
        type: 'in',
        amount: 50000,
        wallet: 'wc',
        at: '2026-09-26T13:30:00+00:00',
      ),
    ];
    expect(detectTransferPairs(items), isEmpty);
  });

  test('satu in hanya dipakai sekali, pilih gap terkecil', () {
    final items = [
      _tx(
        id: 'o1',
        type: 'out',
        amount: 20000,
        wallet: 'wa',
        at: '2026-09-26T12:00:00+00:00',
      ),
      _tx(
        id: 'o2',
        type: 'out',
        amount: 20000,
        wallet: 'wa',
        at: '2026-09-26T12:05:00+00:00',
      ),
      _tx(
        id: 'i1',
        type: 'in',
        amount: 20000,
        wallet: 'wb',
        at: '2026-09-26T12:06:00+00:00',
      ),
    ];
    final pairs = detectTransferPairs(items);
    expect(pairs.length, 1);
    expect(pairs.first.outTx.id, 'o2');
  });

  test('tanpa created_at dilewati', () {
    final items = [
      _tx(id: 'o1', type: 'out', amount: 10000, wallet: 'wa'),
      _tx(id: 'i1', type: 'in', amount: 10000, wallet: 'wb'),
    ];
    expect(detectTransferPairs(items), isEmpty);
  });
}
