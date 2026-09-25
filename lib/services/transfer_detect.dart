import 'package:ssr_space/models/transaction.dart';

/// Satu pasangan kemungkinan transfer antar dompet: keluar dari [fromId]
/// lalu masuk ke [toId] dengan nominal sama dalam jeda singkat.
class TransferPair {
  final SaasTransaction outTx;
  final SaasTransaction inTx;

  const TransferPair({required this.outTx, required this.inTx});

  double get amount => outTx.amount;
}

/// Deteksi pasangan transfer: out + in nominal sama, dompet beda,
/// selisih waktu <= [window], tiap transaksi dipakai maks sekali.
/// Murni saran (badge) — tidak menggabung/mengubah data.
List<TransferPair> detectTransferPairs(
  List<SaasTransaction> items, {
  Duration window = const Duration(minutes: 10),
}) {
  DateTime? at(SaasTransaction t) {
    if (t.createdAt == null || t.createdAt!.isEmpty) return null;
    try {
      return DateTime.parse(t.createdAt!).toLocal();
    } catch (_) {
      return null;
    }
  }

  final outs = items.where((t) {
    return t.type == 'out' && t.walletId != null && t.walletId!.isNotEmpty;
  }).toList();
  final ins = items.where((t) => t.type == 'in').toList();
  final usedIn = <String>{};
  final pairs = <TransferPair>[];

  outs.sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));
  for (final o in outs) {
    final ot = at(o);
    if (ot == null) continue;
    TransferPair? best;
    Duration? bestGap;
    for (final i in ins) {
      if (usedIn.contains(i.id)) continue;
      if (i.amount != o.amount) continue;
      final iw = i.walletId ?? i.toWalletId ?? '';
      if (iw.isEmpty || iw == o.walletId) continue;
      final it = at(i);
      if (it == null) continue;
      final gap = it.difference(ot).abs();
      if (gap > window) continue;
      if (bestGap == null || gap < bestGap) {
        bestGap = gap;
        best = TransferPair(outTx: o, inTx: i);
      }
    }
    if (best != null) {
      usedIn.add(best.inTx.id);
      pairs.add(best);
    }
  }
  return pairs;
}
