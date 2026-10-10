import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/saving.dart';

/// Satu baris agregat RPC month_mix (jenis, kategori, jumlah, cacah).
/// Murni Dart — dasar matematika eksak Beranda/Laporan di skala berapa pun.
class MonthMixRow {
  final String type;
  final String category;
  final double sum;
  const MonthMixRow({
    required this.type,
    required this.category,
    required this.sum,
  });

  factory MonthMixRow.fromMap(Map<String, dynamic> m) => MonthMixRow(
        type: (m['t'] ?? '').toString(),
        category: (m['c'] ?? '').toString(),
        sum: (m['s'] as num?)?.toDouble() ?? 0,
      );
}

/// Angka turunan sebulan: total in/out, iris tabungan, net, dan dua peta
/// kategori lapis-atas (semua-out untuk rekap; tanpa-tabungan untuk
/// banding/health/pace — selaras _totalsFor vs _catTotalsOf laporan).
class MonthFigures {
  final double totalIn;
  final double totalOut;
  final double savingOut;
  final double spendOut;
  final double net;
  final Map<String, double> catTotals;
  final Map<String, double> catTotalsNoSaving;
  final int totalN;
  const MonthFigures({
    required this.totalIn,
    required this.totalOut,
    required this.savingOut,
    required this.spendOut,
    required this.net,
    required this.catTotals,
    required this.catTotalsNoSaving,
    required this.totalN,
  });

  static const empty = MonthFigures(
    totalIn: 0,
    totalOut: 0,
    savingOut: 0,
    spendOut: 0,
    net: 0,
    catTotals: {},
    catTotalsNoSaving: {},
    totalN: 0,
  );
}

/// Lipat baris mix jadi angka. [otherLabel] ganti kategori kosong
/// (disuntik agar murni: tanpa tr di sini).
MonthFigures foldMonthMix(
  List<MonthMixRow> rows, {
  required String otherLabel,
  int totalN = 0,
}) {
  var totalIn = 0.0;
  var totalOut = 0.0;
  var savingOut = 0.0;
  final catTotals = <String, double>{};
  final catTotalsNoSaving = <String, double>{};
  for (final r in rows) {
    if (r.type == 'in') {
      totalIn += r.sum;
      continue;
    }
    if (r.type != 'out') continue; // transfer diabaikan, selaras UI
    totalOut += r.sum;
    final top = topOf(r.category);
    final name = top.isEmpty ? otherLabel : top;
    catTotals[name] = (catTotals[name] ?? 0) + r.sum;
    if (isSavingCategory(r.category)) {
      savingOut += r.sum;
    } else {
      catTotalsNoSaving[name] = (catTotalsNoSaving[name] ?? 0) + r.sum;
    }
  }
  var spendOut = totalOut - savingOut;
  if (spendOut < 0) spendOut = 0;
  return MonthFigures(
    totalIn: totalIn,
    totalOut: totalOut,
    savingOut: savingOut,
    spendOut: spendOut,
    net: totalIn - totalOut,
    catTotals: catTotals,
    catTotalsNoSaving: catTotalsNoSaving,
    totalN: totalN,
  );
}

/// Konverter fallback (RPC belum ada): baris mix dari list transaksi.
List<MonthMixRow> mixRowsFromTx(
  Iterable<Map<String, dynamic>> txs,
) =>
    [
      for (final t in txs)
        MonthMixRow(
          type: (t['type'] ?? '').toString(),
          category: (t['category'] ?? '').toString(),
          sum: (t['amount'] as num?)?.toDouble() ?? 0,
        ),
    ];
