// Ringkasan belanja per anggota workspace: agregasi createdBy.
// Murni Dart (tanpa Flutter). Transfer diabaikan (bukan belanja);
// tanpa pencatat dilewati (tak bisa diatribusikan, bukan dibuang diam:
// pemanggil tetap tampilkan total workspace).

/// Satu transaksi seperlunya agregasi.
class MemberTx {
  final String type;
  final double amount;
  final String? createdBy;
  final String date;

  const MemberTx({
    required this.type,
    required this.amount,
    required this.createdBy,
    required this.date,
  });
}

/// Total per anggota: masuk, keluar, jumlah transaksi.
class MemberTotal {
  final double inTotal;
  final double outTotal;
  final int count;

  const MemberTotal({
    required this.inTotal,
    required this.outTotal,
    required this.count,
  });
}

/// Agregasi bulan [month] ('YYYY-MM') per createdBy.
Map<String, MemberTotal> memberMonthTotals(
  List<MemberTx> txs,
  String month,
) {
  final ins = <String, double>{};
  final outs = <String, double>{};
  final counts = <String, int>{};
  for (final t in txs) {
    final by = t.createdBy ?? '';
    if (by.isEmpty) continue;
    if (!t.date.startsWith(month)) continue;
    if (t.type == 'in') {
      ins[by] = (ins[by] ?? 0) + t.amount;
      counts[by] = (counts[by] ?? 0) + 1;
    } else if (t.type == 'out') {
      outs[by] = (outs[by] ?? 0) + t.amount;
      counts[by] = (counts[by] ?? 0) + 1;
    }
  }
  final ids = {...ins.keys, ...outs.keys, ...counts.keys};
  return {
    for (final id in ids)
      id: MemberTotal(
        inTotal: ins[id] ?? 0,
        outTotal: outs[id] ?? 0,
        count: counts[id] ?? 0,
      ),
  };
}
