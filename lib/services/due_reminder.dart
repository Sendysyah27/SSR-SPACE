// Pengingat jatuh tempo: utang/piutang + tagihan rutin. Murni Dart.
// H-3 & H-1 (tanggal api, bukan notifnya): scheduler memfilter api
// >= hari ini. Tagihan lewat / utang lunas / tanggal rusak tak dijadwal.

import 'debt_track.dart';

/// Input tagihan seperlunya (layar memetakan dari RecurringBill agar
/// file ini tetap tanpa import Flutter).
class DueBillInput {
  final String id;
  final String label;
  final double amount;
  final String nextDue;
  final bool active;

  const DueBillInput({
    required this.id,
    required this.label,
    required this.amount,
    required this.nextDue,
    required this.active,
  });
}

/// Hari hingga tanggal jatuh tempo (negatif = lewat). Null bila rusak.
int? daysUntilDue(String? dueDate, DateTime today) {
  if (dueDate == null || dueDate.length < 10) return null;
  final d = DateTime.tryParse(dueDate.substring(0, 10));
  if (d == null) return null;
  final t = DateTime(today.year, today.month, today.day);
  return DateTime(d.year, d.month, d.day).difference(t).inDays;
}

/// Utang/piutang ber-deadline yang belum lunas.
class DebtDue {
  final DebtRecord record;
  final int daysLeft;

  const DebtDue({required this.record, required this.daysLeft});
}

List<DebtDue> debtDues(List<DebtRecord> debts, DateTime today) {
  final out = <DebtDue>[];
  for (final d in debts) {
    if (d.isSettled) continue;
    final left = daysUntilDue(d.dueDate, today);
    if (left == null) continue;
    out.add(DebtDue(record: d, daysLeft: left));
  }
  out.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
  return out;
}

/// Tagihan aktif (termasuk yang lewat, untuk daftar upcoming).
class BillDue {
  final DueBillInput input;
  final int daysLeft;

  const BillDue({required this.input, required this.daysLeft});
}

List<BillDue> billDues(List<DueBillInput> bills, DateTime today) {
  final out = <BillDue>[];
  for (final b in bills) {
    if (!b.active) continue;
    final left = daysUntilDue(b.nextDue, today);
    if (left == null) continue;
    out.add(BillDue(input: b, daysLeft: left));
  }
  out.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
  return out;
}

/// Satu notifikasi terjadwal: kunci stabil + tanggal api + data mentah
/// (teks final dirakit scheduler pakai tr/amt).
class DueNotif {
  final String key;
  final String kind;
  final String refId;
  final String name;
  final double amount;
  final String date;

  const DueNotif({
    required this.key,
    required this.kind,
    required this.refId,
    required this.name,
    required this.amount,
    required this.date,
  });
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Rencana H-3 & H-1: hanya tanggal api >= hari ini. Teks final
/// dirakit scheduler (butuh tr/amt); di sini bawa data mentah.
List<DueNotif> notifPlan({
  required List<DebtRecord> debts,
  required List<DueBillInput> bills,
  required DateTime today,
}) {
  final t = DateTime(today.year, today.month, today.day);
  final out = <DueNotif>[];
  void add(
    String key,
    String kind,
    String refId,
    String name,
    double amount,
    DateTime fire,
  ) {
    if (fire.isBefore(t)) return;
    out.add(
      DueNotif(
        key: key,
        kind: kind,
        refId: refId,
        name: name,
        amount: amount,
        date: _ymd(fire),
      ),
    );
  }

  for (final d in debts) {
    if (d.isSettled) continue;
    final dueRaw = d.dueDate;
    if (dueRaw == null || dueRaw.length < 10) continue;
    final due = DateTime.tryParse(dueRaw.substring(0, 10));
    if (due == null) continue;
    final kind = d.kind == debtKindDebt ? 'debt' : 'recv';
    add('due:$kind:${d.id}:h3', kind, d.id, d.name, d.remaining(),
        due.subtract(const Duration(days: 3)));
    add('due:$kind:${d.id}:h1', kind, d.id, d.name, d.remaining(),
        due.subtract(const Duration(days: 1)));
  }
  for (final b in bills) {
    if (!b.active || b.nextDue.length < 10) continue;
    final due = DateTime.tryParse(b.nextDue.substring(0, 10));
    if (due == null) continue;
    add('due:bill:${b.id}:h3', 'bill', b.id, b.label, b.amount,
        due.subtract(const Duration(days: 3)));
    add('due:bill:${b.id}:h1', 'bill', b.id, b.label, b.amount,
        due.subtract(const Duration(days: 1)));
  }
  return out;
}
