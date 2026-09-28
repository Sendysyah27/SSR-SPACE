// Baca saldo e-money: parse murni hasil getCardInfo/getHistory.
// Tanpa import Flutter — cek lokal via dart --enable-asserts.
import 'dart:convert';

enum NfcEntryDir { credit, debit, unknown }

NfcEntryDir nfcDirOf(String type) => switch (type) {
      '1' => NfcEntryDir.credit,
      '2001' => NfcEntryDir.debit,
      _ => NfcEntryDir.unknown,
    };

int? parseNfcBalance(String raw) => int.tryParse(raw.trim());

String nfcBankLabel(String bank) {
  final b = bank.trim();
  if (b.isEmpty) return 'UNKNOWN';
  return b.toUpperCase();
}

String maskCardNumber(String number) {
  final n = number.trim();
  if (n.isEmpty) return '-';
  if (n.length < 8) return n;
  return '${n.substring(0, 4)} •••• ${n.substring(n.length - 4)}';
}

class NfcCardEntry {
  final int amount;
  final int balance;
  final int counter;
  final String date;
  final String tid;
  final String type;
  final NfcEntryDir dir;
  const NfcCardEntry({
    required this.amount,
    required this.balance,
    required this.counter,
    required this.date,
    required this.tid,
    required this.type,
    required this.dir,
  });
}

List<NfcCardEntry> parseNfcHistory(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    final out = <NfcCardEntry>[];
    for (final e in decoded) {
      if (e is! Map) continue;
      final amount = (e['amount'] as num?)?.toInt();
      final balance = (e['balance'] as num?)?.toInt();
      final counter = (e['counter'] as num?)?.toInt();
      final date = e['date']?.toString() ?? '';
      final tid = e['tid']?.toString() ?? '';
      final type = e['type']?.toString() ?? '';
      if (amount == null || balance == null || counter == null) continue;
      out.add(NfcCardEntry(
        amount: amount,
        balance: balance,
        counter: counter,
        date: date,
        tid: tid,
        type: type,
        dir: nfcDirOf(type),
      ));
    }
    out.sort((a, b) => b.counter.compareTo(a.counter));
    return out;
  } catch (_) {
    return [];
  }
}

class NfcCard {
  final String uid;
  final String bank;
  final String last4;
  final String label;
  final String? walletId;
  final String addedAt;
  const NfcCard({
    required this.uid,
    required this.bank,
    required this.last4,
    required this.label,
    required this.walletId,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'bank': bank,
        'last4': last4,
        'label': label,
        'walletId': walletId,
        'addedAt': addedAt,
      };

  static NfcCard? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final uid = raw['uid']?.toString() ?? '';
    if (uid.isEmpty) return null;
    return NfcCard(
      uid: uid,
      bank: raw['bank']?.toString() ?? 'UNKNOWN',
      last4: raw['last4']?.toString() ?? '',
      label: raw['label']?.toString() ?? uid,
      walletId: raw['walletId']?.toString(),
      addedAt: raw['addedAt']?.toString() ?? '',
    );
  }
}

class NfcCheck {
  final String uid;
  final String bank;
  final int balance;
  final String at;
  const NfcCheck({
    required this.uid,
    required this.bank,
    required this.balance,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'bank': bank,
        'balance': balance,
        'at': at,
      };

  static NfcCheck? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final uid = raw['uid']?.toString() ?? '';
    final balance = (raw['balance'] as num?)?.toInt();
    final at = raw['at']?.toString() ?? '';
    if (uid.isEmpty || balance == null || DateTime.tryParse(at) == null) {
      return null;
    }
    return NfcCheck(
      uid: uid,
      bank: raw['bank']?.toString() ?? 'UNKNOWN',
      balance: balance,
      at: at,
    );
  }
}

const maxNfcCards = 20;
const maxNfcChecks = 50;

List<T> capList<T>(List<T> all, int max) =>
    all.length <= max ? List<T>.of(all) : all.sublist(0, max);
