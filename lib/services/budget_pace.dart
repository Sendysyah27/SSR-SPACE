/// Pace budget per kategori. Dart murni, offline-first.
///
/// Aman: laju aman sampai akhir bulan. Waspada: proyeksi habis sebelum
/// akhir bulan tapi masih >7 hari. Bahaya: sudah jebol atau diproyeksi
/// habis dalam 7 hari ke depan. Kategori tabungan dikecualikan
/// (pemanggil menyaring, itu target terkumpul bukan batas pakai).
enum PaceState { safe, warn, danger }

class BudgetPace {
  final PaceState state;
  final DateTime? depletedDate;
  final double dailyAvg;
  final double projected;
  const BudgetPace({
    required this.state,
    required this.depletedDate,
    required this.dailyAvg,
    required this.projected,
  });
}

BudgetPace budgetPace({
  required double spent,
  required double limit,
  required DateTime today,
}) {
  final dim = DateTime(today.year, today.month + 1, 0).day;
  final elapsed = today.day.clamp(1, dim);
  if (limit <= 0) {
    return const BudgetPace(
      state: PaceState.safe,
      depletedDate: null,
      dailyAvg: 0,
      projected: 0,
    );
  }
  if (spent >= limit) {
    final avg = spent / elapsed;
    return BudgetPace(
      state: PaceState.danger,
      depletedDate: DateTime(today.year, today.month, today.day),
      dailyAvg: avg,
      projected: avg * dim,
    );
  }
  final avg = spent / elapsed;
  final projected = avg * dim;
  if (avg <= 0 || projected <= limit) {
    return BudgetPace(
      state: PaceState.safe,
      depletedDate: null,
      dailyAvg: avg,
      projected: projected,
    );
  }
  final daysNeeded = (limit / avg).ceil().clamp(1, dim);
  final date = DateTime(today.year, today.month, 1)
      .add(Duration(days: daysNeeded - 1));
  final daysToDeplete = daysNeeded - elapsed;
  final state =
      daysToDeplete <= 7 ? PaceState.danger : PaceState.warn;
  return BudgetPace(
    state: state,
    depletedDate: date,
    dailyAvg: avg,
    projected: projected,
  );
}
