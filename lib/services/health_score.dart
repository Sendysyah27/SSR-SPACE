/// Financial health score harian (0-100). Dart murni, offline-first:
/// semua input angka yang sudah dihitung pemanggil, tanpa query di sini.
///
/// Bobot: kepatuhan budget 40%, rasio nabung 30%, tren belanja 20%,
/// streak 10%. Tiap komponen 0-100, total dibulatkan.
class HealthBudget {
  final double limit;
  final double spent;
  const HealthBudget({required this.limit, required this.spent});
}

class HealthBreakdown {
  final int total;
  final int budget;
  final int saving;
  final int trend;
  final int streak;
  const HealthBreakdown({
    required this.total,
    required this.budget,
    required this.saving,
    required this.trend,
    required this.streak,
  });
}

int _clamp100(num v) => v.round().clamp(0, 100).toInt();

/// Skor budget: 100 bila tak ada yang jebol, turun sebanding total
/// jebol vs total limit. Tanpa budget apa pun = 70 (netral, bukan
/// hukuman). Hanya terima budget non-tabungan (pemanggil menyaring).
int budgetScore(List<HealthBudget> budgets) {
  var totalLimit = 0.0;
  var totalOver = 0.0;
  for (final b in budgets) {
    if (b.limit <= 0) continue;
    totalLimit += b.limit;
    final over = b.spent - b.limit;
    if (over > 0) totalOver += over;
  }
  if (totalLimit <= 0) return 70;
  return _clamp100(100 * (1 - totalOver / totalLimit));
}

/// Skor nabung: rasio tabungan vs pemasukan, target 20% = 100.
/// Tanpa pemasukan: 100 bila ada tabungan, 50 bila tak ada data.
int savingScore({required double savingOut, required double totalIn}) {
  if (totalIn <= 0) return savingOut > 0 ? 100 : 50;
  return _clamp100(savingOut / totalIn / 0.2 * 100);
}

/// Skor tren: belanja non-tabungan bulan ini vs bulan lalu.
/// Turun = bagus, naik = buruk. Tanpa bulan lalu: 70 bila bulan ini
/// juga nol, 50 bila ada belanja tanpa pembanding.
int trendScore({required double curOut, required double prevOut}) {
  if (prevOut <= 0) return curOut <= 0 ? 70 : 50;
  final change = (curOut - prevOut) / prevOut;
  return _clamp100(100 - change * 100);
}

/// Skor streak: 30 hari = 100, skala linear.
int streakScore(int days) {
  if (days <= 0) return 0;
  return _clamp100(days / 30 * 100);
}

HealthBreakdown computeHealth({
  required double totalIn,
  required List<HealthBudget> budgets,
  required double savingOut,
  required double curOut,
  required double prevOut,
  required int streakDays,
}) {
  final b = budgetScore(budgets);
  final s = savingScore(savingOut: savingOut, totalIn: totalIn);
  final t = trendScore(curOut: curOut, prevOut: prevOut);
  final st = streakScore(streakDays);
  final total = _clamp100(b * 0.4 + s * 0.3 + t * 0.2 + st * 0.1);
  return HealthBreakdown(
    total: total,
    budget: b,
    saving: s,
    trend: t,
    streak: st,
  );
}
