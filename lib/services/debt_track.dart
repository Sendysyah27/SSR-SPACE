// Utang-piutang tracker: catatan + bayar sebagian/penuh + total sisa.
// Murni Dart (tanpa Flutter/Supabase). Simpan di prefs `debts`
// (maks 50, pola bill_split). Utang = gua berutang ke orang;
// piutang = orang berutang ke gua. Lunas = status + riwayat bayar.

/// Maksimal catatan tersimpan.
const maxDebts = 50;

/// Jenis catatan: utang (gua bayar) atau piutang (gua terima).
const debtKindDebt = 'debt';
const debtKindReceivable = 'receivable';

/// Satu pembayaran: nominal + tanggal. Cap pembayaran jahat di parse.
class DebtPayment {
  final double amount;
  final String date;

  const DebtPayment({required this.amount, required this.date});

  Map<String, dynamic> toJson() => {'amount': amount, 'date': date};

  static DebtPayment? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final amount = (raw['amount'] as num?)?.toDouble();
    final date = raw['date']?.toString() ?? '';
    if (amount == null || amount <= 0) return null;
    if (date.length < 10 || DateTime.tryParse(date.substring(0, 10)) == null) {
      return null;
    }
    return DebtPayment(amount: amount, date: date.substring(0, 10));
  }
}

/// Satu catatan utang/piutang beserta riwayat bayarnya.
class DebtRecord {
  final String id;
  final String kind;
  final String name;
  final double total;
  final String date;
  final String? dueDate;
  final String note;
  final List<DebtPayment> payments;

  const DebtRecord({
    required this.id,
    required this.kind,
    required this.name,
    required this.total,
    required this.date,
    this.dueDate,
    required this.note,
    required this.payments,
  });

  /// Sudah dibayar (jumlah riwayat).
  double get paidTotal => payments.fold(0, (a, p) => a + p.amount);

  /// Sisa (tak pernah negatif walau riwayat kelebihan).
  double remaining() {
    final rest = total - paidTotal;
    return rest < 0 ? 0 : rest;
  }

  /// True bila sisa nol.
  bool get isSettled => remaining() <= 0;

  /// Tambah pembayaran; kelebihan di-cap di sisa (backstop, UI menolak
  /// duluan via [validatePayment]).
  DebtRecord applyPayment(DebtPayment p) {
    final rest = remaining();
    final amt = p.amount > rest ? rest : p.amount;
    if (amt <= 0) return this;
    return DebtRecord(
      id: id,
      kind: kind,
      name: name,
      total: total,
      date: date,
      dueDate: dueDate,
      note: note,
      payments: [...payments, DebtPayment(amount: amt, date: p.date)],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'name': name,
    'total': total,
    'date': date,
    if (dueDate != null) 'dueDate': dueDate,
    'note': note,
    'payments': [for (final p in payments) p.toJson()],
  };

  /// Parse toleran: null bila bentuk tak dikenal (entri rusak dibuang).
  static DebtRecord? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString() ?? '';
    final kind = raw['kind']?.toString() ?? '';
    final name = (raw['name']?.toString() ?? '').trim();
    final total = (raw['total'] as num?)?.toDouble();
    final date = raw['date']?.toString() ?? '';
    if (id.isEmpty ||
        (kind != debtKindDebt && kind != debtKindReceivable) ||
        name.isEmpty ||
        total == null ||
        total <= 0) {
      return null;
    }
    if (date.length < 10 || DateTime.tryParse(date.substring(0, 10)) == null) {
      return null;
    }
    // Deadline opsional: absen/rusak = null (entri lama tetap valid).
    String? dueDate;
    final rawDue = raw['dueDate']?.toString() ?? '';
    if (rawDue.length >= 10 && DateTime.tryParse(rawDue.substring(0, 10)) != null) {
      dueDate = rawDue.substring(0, 10);
    }
    final payments = <DebtPayment>[];
    final list = raw['payments'];
    if (list is List) {
      for (final e in list) {
        final p = DebtPayment.tryParse(e);
        if (p != null) payments.add(p);
        if (payments.length >= 200) break;
      }
    }
    return DebtRecord(
      id: id,
      kind: kind,
      name: name,
      total: total,
      date: date.substring(0, 10),
      dueDate: dueDate,
      note: (raw['note']?.toString() ?? '').trim(),
      payments: payments,
    );
  }
}

/// Total sisa: utang (gua bayar) vs piutang (gua terima).
({double debt, double receivable}) debtTotals(List<DebtRecord> all) {
  var debt = 0.0;
  var receivable = 0.0;
  for (final d in all) {
    if (d.kind == debtKindDebt) {
      debt += d.remaining();
    } else {
      receivable += d.remaining();
    }
  }
  return (debt: debt, receivable: receivable);
}

/// Validasi nominal bayar: null bila ok, kode bila tidak.
/// 'nonPositive' = nol/negatif, 'over' = melebihi sisa.
String? validatePayment(DebtRecord record, double amount) {
  if (amount <= 0) return 'nonPositive';
  if (amount > record.remaining()) return 'over';
  return null;
}

String newDebtId() => DateTime.now().millisecondsSinceEpoch.toString();
