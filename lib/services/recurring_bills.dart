import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tagihan rutin: saran sekali ketuk, bukan insert otomatis (P2).
///
/// Disimpan di prefs `recurring_bills` sebagai list JSON (maks 30):
/// id, label, amount (minor IDR), category, walletId, period
/// (`weekly`/`monthly`), anchorDay, nextDue (YYYY-MM-DD), active.
/// Insert hasil = baris `transactions` normal via TxInputSheet (prefill).
const maxBills = 30;

class RecurringBill {
  final String id;
  final String label;
  final double amount;
  final String category;
  final String walletId;
  final String period;
  final int anchorDay;
  final String nextDue;
  final bool active;

  const RecurringBill({
    required this.id,
    required this.label,
    required this.amount,
    required this.category,
    required this.walletId,
    required this.period,
    required this.anchorDay,
    required this.nextDue,
    required this.active,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amount': amount,
        'category': category,
        'walletId': walletId,
        'period': period,
        'anchorDay': anchorDay,
        'nextDue': nextDue,
        'active': active,
      };

  /// Parse toleran: null bila bentuk tak dikenal (entri rusak dibuang).
  static RecurringBill? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString() ?? '';
    final label = (raw['label']?.toString() ?? '').trim();
    final amount = (raw['amount'] as num?)?.toDouble();
    final walletId = raw['walletId']?.toString() ?? '';
    final period = raw['period']?.toString() ?? '';
    final anchor = (raw['anchorDay'] as num?)?.toInt();
    final nextDue = raw['nextDue']?.toString() ?? '';
    if (id.isEmpty ||
        label.isEmpty ||
        amount == null ||
        amount <= 0 ||
        walletId.isEmpty ||
        (period != 'weekly' && period != 'monthly') ||
        anchor == null ||
        anchor < 1 ||
        anchor > 31 ||
        nextDue.length < 10 ||
        DateTime.tryParse(nextDue) == null) {
      return null;
    }
    return RecurringBill(
      id: id,
      label: label,
      amount: amount,
      category: (raw['category']?.toString() ?? '').trim(),
      walletId: walletId,
      period: period,
      anchorDay: anchor,
      nextDue: nextDue.substring(0, 10),
      active: raw['active'] != false,
    );
  }

  RecurringBill copyWith({
    String? label,
    double? amount,
    String? category,
    String? walletId,
    String? period,
    int? anchorDay,
    String? nextDue,
    bool? active,
  }) =>
      RecurringBill(
        id: id,
        label: label ?? this.label,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        walletId: walletId ?? this.walletId,
        period: period ?? this.period,
        anchorDay: anchorDay ?? this.anchorDay,
        nextDue: nextDue ?? this.nextDue,
        active: active ?? this.active,
      );
}

/// Jatuh tempo bulanan: jangkar dijepit ke hari terakhir bulan.
DateTime monthlyDue(int year, int month, int anchorDay) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, anchorDay > last ? last : anchorDay);
}

/// Majukan [bill] satu periode dari tanggal jatuh tempo [from].
/// Mingguan: +7 hari. Bulanan: bulan berikut di tanggal jangkar (jepit).
DateTime advanceBill(RecurringBill bill, DateTime from) {
  final day = DateTime(from.year, from.month, from.day);
  if (bill.period == 'weekly') return day.add(const Duration(days: 7));
  var y = day.year;
  var m = day.month + 1;
  if (m > 12) {
    m = 1;
    y += 1;
  }
  return monthlyDue(y, m, bill.anchorDay);
}

/// True bila [bill] aktif dan nextDue sudah lewat (<= hari [today]).
bool isBillDue(RecurringBill bill, DateTime today) {
  if (!bill.active) return false;
  final d = DateTime.tryParse(bill.nextDue);
  if (d == null) return false;
  final due = DateTime(d.year, d.month, d.day);
  final t = DateTime(today.year, today.month, today.day);
  return !due.isAfter(t);
}

List<RecurringBill> dueBills(List<RecurringBill> all, DateTime today) =>
    all.where((b) => isBillDue(b, today)).toList();

/// Nonaktifkan item yang dompetnya sudah dihapus (pesan jelas di UI,
/// bukan insert yatim).
List<RecurringBill> markWalletGone(
  List<RecurringBill> all,
  Set<String> existingWalletIds,
) =>
    all
        .map((b) => existingWalletIds.contains(b.walletId)
            ? b
            : b.copyWith(active: false))
        .toList();

String newBillId() => DateTime.now().millisecondsSinceEpoch.toString();

/// Satu pembayaran tercatat: tagihan apa, jatuh tempo mana yang dibayar,
/// nominal saat dibayar, dan kapan dicatat. Nominal bisa beda dari
/// [RecurringBill.amount] bila user mengubahnya di sheet.
class PaymentEntry {
  final String billId;
  final String date;
  final double amount;
  final String paidAt;

  const PaymentEntry({
    required this.billId,
    required this.date,
    required this.amount,
    required this.paidAt,
  });

  Map<String, dynamic> toJson() => {
        'billId': billId,
        'date': date,
        'amount': amount,
        'paidAt': paidAt,
      };

  static PaymentEntry? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final billId = raw['billId']?.toString() ?? '';
    final date = raw['date']?.toString() ?? '';
    final amount = (raw['amount'] as num?)?.toDouble();
    final paidAt = raw['paidAt']?.toString() ?? '';
    if (billId.isEmpty ||
        date.length < 10 ||
        DateTime.tryParse(date) == null ||
        amount == null ||
        amount <= 0 ||
        paidAt.isEmpty) {
      return null;
    }
    return PaymentEntry(
      billId: billId,
      date: date.substring(0, 10),
      amount: amount,
      paidAt: paidAt,
    );
  }
}

/// Hasil pencatatan: tagihan dengan nextDue maju + entri riwayat.
/// [paidDate] = nextDue yang dibayar (sebelum maju), [amount] = nominal
/// yang benar dibayar (ikut sheet bila diubah, bukan master).
({RecurringBill bill, PaymentEntry entry}) recordPayment(
  RecurringBill bill,
  String paidDate,
  double amount,
  DateTime now,
) {
  final from = DateTime.tryParse(paidDate) ?? DateTime(now.year, now.month, now.day);
  final advanced = advanceBill(bill, from);
  return (
    bill: bill.copyWith(nextDue: _ymd(advanced)),
    entry: PaymentEntry(
      billId: bill.id,
      date: paidDate.substring(0, 10),
      amount: amount,
      paidAt: now.toIso8601String(),
    ),
  );
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Riwayat satu tagihan, terbaru dulu.
List<PaymentEntry> historyFor(List<PaymentEntry> all, String billId) {
  final out = all.where((e) => e.billId == billId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return out;
}

const _kPayments = 'recurring_payments';
const maxPayments = 200;

Future<List<PaymentEntry>> loadPayments() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kPayments);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    final out = <PaymentEntry>[];
    for (final e in list) {
      final p = PaymentEntry.tryParse(e);
      if (p != null) out.add(p);
      if (out.length >= maxPayments) break;
    }
    return out;
  } catch (_) {
    return [];
  }
}

Future<void> savePayments(List<PaymentEntry> entries) async {
  final capped = entries.take(maxPayments).toList();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _kPayments,
    jsonEncode([for (final e in capped) e.toJson()]),
  );
}

const _kBills = 'recurring_bills';

Future<List<RecurringBill>> loadBills() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kBills);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    final out = <RecurringBill>[];
    for (final e in list) {
      final b = RecurringBill.tryParse(e);
      if (b != null) out.add(b);
      if (out.length >= maxBills) break;
    }
    return out;
  } catch (_) {
    return [];
  }
}

Future<void> saveBills(List<RecurringBill> bills) async {
  final capped = bills.take(maxBills).toList();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _kBills,
    jsonEncode([for (final b in capped) b.toJson()]),
  );
}
