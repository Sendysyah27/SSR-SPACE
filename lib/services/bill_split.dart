// Patungan (bill splitter): hitungan bagi + utang + progres lunas.
// Murni Dart (tanpa Flutter/Supabase). Simpan di prefs `bill_splits`
// (maks 30, pola recurring_bills). Lunas = status saja, tanpa transaksi.

/// Maksimal split tersimpan (pola recurring_bills).
const maxSplits = 30;

/// Satu porsi peserta.
class SplitShare {
  final String userId;
  final double amount;

  const SplitShare({required this.userId, required this.amount});

  Map<String, dynamic> toJson() => {'userId': userId, 'amount': amount};

  static SplitShare? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final userId = raw['userId']?.toString() ?? '';
    final amount = (raw['amount'] as num?)?.toDouble();
    if (userId.isEmpty || amount == null || amount < 0) return null;
    return SplitShare(userId: userId, amount: amount);
  }
}

/// Satu patungan: judul, total, siapa membayar dulu, porsi tiap peserta,
/// dan siapa saja yang sudah lunas (userId).
class SplitBill {
  final String id;
  final String title;
  final String txId;
  final double total;
  final String payerId;
  final List<SplitShare> shares;
  final Set<String> settled;

  const SplitBill({
    required this.id,
    required this.title,
    required this.txId,
    required this.total,
    required this.payerId,
    required this.shares,
    required this.settled,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'txId': txId,
    'total': total,
    'payerId': payerId,
    'shares': [for (final s in shares) s.toJson()],
    'settled': settled.toList(),
  };

  /// Parse toleran: null bila bentuk tak dikenal (entri rusak dibuang).
  static SplitBill? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString() ?? '';
    final title = (raw['title']?.toString() ?? '').trim();
    final total = (raw['total'] as num?)?.toDouble();
    final payerId = raw['payerId']?.toString() ?? '';
    final list = raw['shares'];
    if (id.isEmpty ||
        title.isEmpty ||
        total == null ||
        total <= 0 ||
        payerId.isEmpty ||
        list is! List ||
        list.isEmpty) {
      return null;
    }
    final shares = <SplitShare>[];
    for (final e in list) {
      final s = SplitShare.tryParse(e);
      if (s != null) shares.add(s);
      if (shares.length >= 50) break;
    }
    if (shares.isEmpty) return null;
    final settled = <String>{};
    final rawSettled = raw['settled'];
    if (rawSettled is List) {
      for (final e in rawSettled) {
        final v = e?.toString() ?? '';
        if (v.isNotEmpty) settled.add(v);
      }
    }
    return SplitBill(
      id: id,
      title: title,
      txId: raw['txId']?.toString() ?? '',
      total: total,
      payerId: payerId,
      shares: shares,
      settled: settled,
    );
  }

  SplitBill copyWith({List<SplitShare>? shares, Set<String>? settled}) =>
      SplitBill(
        id: id,
        title: title,
        txId: txId,
        total: total,
        payerId: payerId,
        shares: shares ?? this.shares,
        settled: settled ?? this.settled,
      );
}

/// Satu utang: [from] berutang [amount] ke [to] (pembayar).
class BillDebt {
  final String from;
  final String to;
  final double amount;

  const BillDebt({required this.from, required this.to, required this.amount});
}

/// Bagi rata ke rupiah bulat; sisa rupiah jatuh ke peserta pertama
/// supaya jumlah selalu pas dengan total. Id kosong = {}.
Map<String, double> equalShares(double total, List<String> ids) {
  if (ids.isEmpty) return {};
  final whole = total.round();
  final base = whole ~/ ids.length;
  final rest = whole - base * ids.length;
  final out = <String, double>{};
  for (var i = 0; i < ids.length; i++) {
    out[ids[i]] = (base + (i == 0 ? rest : 0)).toDouble();
  }
  return out;
}

/// Validasi porsi custom: null bila ok, kode error bila tidak.
/// 'empty' = tanpa peserta, 'nonPositive' = ada porsi <= 0,
/// 'mismatch' = jumlah != total.
String? validateCustomShares(double total, Map<String, double> m) {
  if (m.isEmpty) return 'empty';
  if (m.values.any((v) => v <= 0)) return 'nonPositive';
  if (m.values.fold(0.0, (a, b) => a + b) != total) return 'mismatch';
  return null;
}

/// Daftar utang belum lunas: tiap peserta (kecuali pembayar dan yang
/// sudah lunas) berutang porsinya ke pembayar.
List<BillDebt> debtsOf(SplitBill bill) => [
  for (final s in bill.shares)
    if (s.userId != bill.payerId && !bill.settled.contains(s.userId))
      BillDebt(from: s.userId, to: bill.payerId, amount: s.amount),
];

/// Jumlah peserta (termasuk pembayar).
int shareCount(SplitBill bill) => bill.shares.length;

/// Jumlah utang yang sudah lunas (di luar pembayar).
int settledCount(SplitBill bill) =>
    bill.shares
        .where(
          (s) => s.userId != bill.payerId && bill.settled.contains(s.userId),
        )
        .length;

/// True bila semua utang lunas.
bool isFullySettled(SplitBill bill) => debtsOf(bill).isEmpty;

/// Label peserta: 8 char ID + penanda saya (anggota tanpa nama, privasi).
/// [meSuffix] diisi dari strings (`bs_me`) agar ikut bahasa app.
String shortMemberLabel(String userId, bool isMe, {String meSuffix = 'Saya'}) {
  final short = userId.length <= 8 ? userId : userId.substring(0, 8);
  return isMe && meSuffix.isNotEmpty ? '$short · $meSuffix' : short;
}

String newSplitId() => DateTime.now().millisecondsSinceEpoch.toString();
