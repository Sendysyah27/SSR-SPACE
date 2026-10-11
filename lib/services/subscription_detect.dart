// Pelacak langganan: deteksi pola bayar berulang dari riwayat.
// Murni Dart (tanpa Flutter/Supabase) supaya bisa di-test lokal.
//
// Aturan grup: label ternormalisasi + nominal sama persis.
// Aturan interval: tiap jeda bayar berurutan 21-40 hari (~30 hari).
// 3x+ konsisten = Pasti, 2x = Mungkin. Mingguan dan acak ditolak.

/// Jeda minimum/maksimum antar bayar agar dihitung langganan bulanan.
const subMinGapDays = 21;
const subMaxGapDays = 40;

/// Satu pembayaran keluar, siap deteksi (disaring dari SaasTransaction
/// di layar: hanya `out`, nominal > 0, tanggal valid).
class SubPayment {
  final String date;
  final double amount;
  final String label;
  final String type;
  final bool auto;
  final String walletId;
  final String category;

  const SubPayment({
    required this.date,
    required this.amount,
    required this.label,
    this.type = 'out',
    this.auto = false,
    this.walletId = '',
    this.category = '',
  });
}

/// Satu pola langganan terdeteksi.
class SubscriptionCandidate {
  final String key;
  final String label;
  final double amount;
  final int count;
  final int avgIntervalDays;
  final String lastDate;
  final bool probable;
  final bool auto;
  final String walletId;
  final String category;

  const SubscriptionCandidate({
    required this.key,
    required this.label,
    required this.amount,
    required this.count,
    required this.avgIntervalDays,
    required this.lastDate,
    required this.probable,
    required this.auto,
    required this.walletId,
    required this.category,
  });
}

/// Normalisasi label: kecil + rapikan spasi. Kunci grup, bukan pajangan.
String normalizeSubLabel(String raw) =>
    raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Kunci grup + kunci prefs abaikan: label ternormalisasi + nominal bulat.
String subGroupKey(String label, double amount) =>
    '${normalizeSubLabel(label)}|${amount.round()}';

DateTime? _day(String date) {
  if (date.length < 10) return null;
  return DateTime.tryParse(date.substring(0, 10));
}

/// Kelompokkan [payments] jadi kandidat langganan.
/// Urut: Pasti dulu, lalu nominal terbesar.
List<SubscriptionCandidate> detectSubscriptions(List<SubPayment> payments) {
  final groups = <String, List<SubPayment>>{};
  for (final p in payments) {
    if (p.type != 'out' || p.amount <= 0) continue;
    if (normalizeSubLabel(p.label).isEmpty) continue;
    if (_day(p.date) == null) continue;
    groups.putIfAbsent(subGroupKey(p.label, p.amount), () => []).add(p);
  }
  final out = <SubscriptionCandidate>[];
  for (final entry in groups.entries) {
    final rows = entry.value
      ..sort((a, b) => a.date.substring(0, 10).compareTo(b.date.substring(0, 10)));
    if (rows.length < 2) continue;
    final gaps = <int>[];
    var ok = true;
    for (var i = 1; i < rows.length; i++) {
      final gap = _day(rows[i].date)!
          .difference(_day(rows[i - 1].date)!)
          .inDays;
      if (gap < subMinGapDays || gap > subMaxGapDays) {
        ok = false;
        break;
      }
      gaps.add(gap);
    }
    if (!ok) continue;
    final last = rows.last;
    final avg = gaps.reduce((a, b) => a + b) / gaps.length;
    out.add(
      SubscriptionCandidate(
        key: entry.key,
        label: last.label.trim(),
        amount: rows.first.amount,
        count: rows.length,
        avgIntervalDays: avg.round(),
        lastDate: last.date.substring(0, 10),
        probable: rows.length >= 3,
        auto: rows.any((r) => r.auto),
        walletId: last.walletId,
        category: last.category,
      ),
    );
  }
  out.sort((a, b) {
    if (a.probable != b.probable) return a.probable ? -1 : 1;
    return b.amount.compareTo(a.amount);
  });
  return out;
}

/// Total beban per bulan = jumlah nominal semua kandidat.
double subscriptionMonthlyTotal(List<SubscriptionCandidate> cands) =>
    cands.fold(0, (sum, c) => sum + c.amount);

/// True bila [label] sudah ada sebagai tagihan rutin (tak sensitif kapital).
bool isKnownLabel(String label, List<String> known) {
  final norm = normalizeSubLabel(label);
  if (norm.isEmpty) return false;
  return known.any((k) => normalizeSubLabel(k) == norm);
}
