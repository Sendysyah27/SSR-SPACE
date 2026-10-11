// Kekayaan bersih: aset (dompet + piutang) minus utang.
// Murni Dart (tanpa Flutter). Tren = estimasi walk-back jujur dari
// arus kas bulanan (asumsi utang konstan; ditulis di subtitle UI).

/// Hasil hitung kekayaan bersih.
class NetWorth {
  final double liquid;
  final double savings;
  final double investments;
  final double receivable;
  final double debt;

  const NetWorth({
    required this.liquid,
    required this.savings,
    required this.investments,
    required this.receivable,
    required this.debt,
  });

  double get assets => liquid + savings + investments + receivable;
  double get net => assets - debt;

  /// False bila tak ada data sama sekali (kartu sembunyi).
  bool get hasData =>
      liquid != 0 ||
      savings != 0 ||
      investments != 0 ||
      receivable != 0 ||
      debt != 0;
}

/// Rakit dari komponen. Tanpa validasi (angka apa adanya).
NetWorth netWorth({
  required double liquid,
  required double savings,
  required double investments,
  required double receivable,
  required double debt,
}) => NetWorth(
  liquid: liquid,
  savings: savings,
  investments: investments,
  receivable: receivable,
  debt: debt,
);

/// Estimasi posisi akhir tiap bulan lampau dari kini mundur.
/// [pastMonthlyNets] = net flow per bulan, terurut tua-ke-muda
/// (bulan berjalan tak ikut; titik kini di-append pemanggil).
/// Contoh: kini 1000, lalu [-50], 2-lalu [+100] -> [950, 1050].
List<double> walkBackEstimates({
  required double currentNet,
  required List<double> pastMonthlyNets,
}) {
  final pts = <double>[];
  var after = 0.0;
  for (final net in pastMonthlyNets) {
    after += net;
  }
  for (final net in pastMonthlyNets) {
    pts.add(currentNet - after);
    after -= net;
  }
  return pts;
}
