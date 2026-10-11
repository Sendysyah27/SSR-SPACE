// Prakiraan arus kas 30 hari: run-rate + tagihan terjadwal.
// Murni Dart (tanpa Flutter/Supabase). Skenario waspada: tagihan
// dihitung di atas run-rate (mungkin double-count bila tagihan sudah
// tercermin di pola — ditulis jujur di subtitle UI, bukan disembunyikan).

/// Jendela proyeksi default (hari).
const forecastDays = 30;

/// Satu arus kas harian (masukan run-rate).
class TxFlow {
  final String date;
  final String type;
  final double amount;

  const TxFlow({required this.date, required this.type, required this.amount});
}

/// Satu tagihan jatuh tempo (masukan kurva).
class BillDue {
  final String nextDue;
  final double amount;
  final bool active;

  const BillDue({
    required this.nextDue,
    required this.amount,
    required this.active,
  });
}

/// Tagihan dalam window, siap dikurangkan di tanggalnya.
class DueBill {
  final String date;
  final double amount;

  const DueBill({required this.date, required this.amount});
}

/// Rata-rata harian (transfer + tanggal rusak diabaikan).
({double inPerDay, double outPerDay}) dailyRate(List<TxFlow> txs, int days) {
  if (days <= 0) return (inPerDay: 0, outPerDay: 0);
  var tin = 0.0;
  var tout = 0.0;
  for (final t in txs) {
    if (t.date.length < 10) continue;
    if (DateTime.tryParse(t.date.substring(0, 10)) == null) continue;
    if (t.type == 'in') {
      tin += t.amount;
    } else if (t.type == 'out') {
      tout += t.amount;
    }
  }
  return (inPerDay: tin / days, outPerDay: tout / days);
}

/// Tagihan aktif jatuh tempo (from, from+days] — hari-ini dianggap sudah
/// tercermin di saldo. Tanggal rusak / nominal <= 0 dibuang.
List<DueBill> upcomingBills(List<BillDue> bills, String fromDate, int days) {
  final from = DateTime.tryParse(
    fromDate.length >= 10 ? fromDate.substring(0, 10) : fromDate,
  );
  if (from == null || days <= 0) return [];
  final out = <DueBill>[];
  for (final b in bills) {
    if (!b.active || b.amount <= 0) continue;
    if (b.nextDue.length < 10) continue;
    final d = DateTime.tryParse(b.nextDue.substring(0, 10));
    if (d == null) continue;
    final gap = d.difference(from).inDays;
    if (gap < 1 || gap > days) continue;
    out.add(DueBill(date: b.nextDue.substring(0, 10), amount: b.amount));
  }
  return out;
}

/// Hasil proyeksi: titik harian (indeks 0 = saldo awal) + min + akhir.
class CashForecast {
  final List<double> points;
  final double end;
  final double min;
  final int minDay;

  const CashForecast({
    required this.points,
    required this.end,
    required this.min,
    required this.minDay,
  });
}

/// Proyeksi: tiap hari tambah net run-rate, kurangi tagihan di tanggalnya.
CashForecast projectForecast({
  required double start,
  required double inPerDay,
  required double outPerDay,
  required List<DueBill> dues,
  required String fromDate,
  int days = forecastDays,
}) {
  final from = DateTime.tryParse(
    fromDate.length >= 10 ? fromDate.substring(0, 10) : fromDate,
  );
  final byDay = <int, double>{};
  if (from != null) {
    for (final d in dues) {
      final dt = DateTime.tryParse(d.date);
      if (dt == null) continue;
      final gap = dt.difference(from).inDays;
      if (gap < 1 || gap > days) continue;
      byDay[gap] = (byDay[gap] ?? 0) + d.amount;
    }
  }
  final points = <double>[start];
  var cur = start;
  for (var d = 1; d <= days; d++) {
    cur += inPerDay - outPerDay - (byDay[d] ?? 0);
    points.add(cur);
  }
  var min = points[0];
  var minDay = 0;
  for (var i = 1; i < points.length; i++) {
    if (points[i] < min) {
      min = points[i];
      minDay = i;
    }
  }
  return CashForecast(
    points: points,
    end: points.last,
    min: min,
    minDay: minDay,
  );
}
