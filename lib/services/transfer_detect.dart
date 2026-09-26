import 'package:ssr_space/models/transaction.dart';

/// Satu pasangan kemungkinan transfer antar dompet: keluar dari [fromId]
/// lalu masuk ke [toId] dengan nominal sama dalam jeda singkat.
class TransferPair {
  final SaasTransaction outTx;
  final SaasTransaction inTx;

  const TransferPair({required this.outTx, required this.inTx});

  double get amount => outTx.amount;
}

class _Candidate {
  final SaasTransaction outTx;
  final SaasTransaction inTx;
  final Duration gap;
  const _Candidate(this.outTx, this.inTx, this.gap);
}

/// Deteksi pasangan transfer: out + in nominal sama, dompet beda,
/// selisih waktu <= [window], tiap transaksi dipakai maks sekali.
/// Kandidat dipasangkan mulai dari gap terkecil (global), agar satu
/// transaksi `in` yang diperebutkan jatuh ke `out` terdekat.
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
  outs.sort((a, b) => (a.createdAt ?? '').compareTo(b.createdAt ?? ''));

  final cands = <_Candidate>[];
  for (final o in outs) {
    final ot = at(o);
    if (ot == null) continue;
    for (final i in ins) {
      if (i.amount != o.amount) continue;
      final iw = i.walletId ?? i.toWalletId ?? '';
      if (iw.isEmpty || iw == o.walletId) continue;
      final it = at(i);
      if (it == null) continue;
      final gap = it.difference(ot).abs();
      if (gap > window) continue;
      cands.add(_Candidate(o, i, gap));
    }
  }
  cands.sort((a, b) => a.gap.compareTo(b.gap));

  final usedOut = <String>{};
  final usedIn = <String>{};
  final pairs = <TransferPair>[];
  for (final c in cands) {
    if (usedOut.contains(c.outTx.id) || usedIn.contains(c.inTx.id)) continue;
    usedOut.add(c.outTx.id);
    usedIn.add(c.inTx.id);
    pairs.add(TransferPair(outTx: c.outTx, inTx: c.inTx));
  }
  return pairs;
}
