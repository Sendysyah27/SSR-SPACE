import 'package:flutter/foundation.dart';

class SaasTransaction {
  final String id;
  final String orgId;
  final String type;
  final double amount;
  final String? walletId;
  final String? toWalletId;
  final String? category;
  final String? note;
  final String? date;
  final String? code;
  final String? createdAt;
  final String? sourcePackage;
  final String? sourceHash;
  final String? createdBy;
  SaasTransaction({
    required this.id,
    required this.orgId,
    required this.type,
    required this.amount,
    this.walletId,
    this.toWalletId,
    this.category,
    this.note,
    this.date,
    this.code,
    this.createdAt,
    this.sourcePackage,
    this.sourceHash,
    this.createdBy,
  });
  factory SaasTransaction.fromMap(Map<String, dynamic> m) => SaasTransaction(
        id: _req(m, 'id'),
        orgId: _req(m, 'org_id'),
        type: (m['type'] ?? '').toString(),
        amount: (m['amount'] as num).toDouble(),
        walletId: m['wallet_id']?.toString(),
        toWalletId: m['to_wallet_id']?.toString(),
        category: m['category']?.toString(),
        note: m['note']?.toString(),
        date: m['date']?.toString(),
        code: m['code']?.toString(),
        createdAt: m['created_at']?.toString(),
        sourcePackage: m['source_package']?.toString(),
        sourceHash: m['source_hash']?.toString(),
        createdBy: m['created_by']?.toString(),
      );


  /// Field wajib: field hilang -> ArgumentError eksplisit
  /// (bukan string "null" yang lolos diam-diam).
  static String _req(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) {
      throw ArgumentError('SaasTransaction.fromMap: field wajib "$key" hilang');
    }
    return v.toString();
  }

  /// Varian defensif [fromMap]: baris rusak -> null (di-skip pemanggil)
  /// alih-alih menumbangkan seluruh list. Hanya untuk mapping list;
  /// get satuan tetap pakai [fromMap] agar error ketahuan.
  static SaasTransaction? tryFromMap(Map<String, dynamic> m) {
    try {
      return SaasTransaction.fromMap(m);
    } catch (e) {
      debugPrint('[SaasTransaction] skip baris rusak: $e');
      return null;
    }
  }

  /// Kebalikan fromMap (cache offline). Key identik supaya round-trip utuh.
  Map<String, dynamic> toMap() => {
        'id': id,
        'org_id': orgId,
        'type': type,
        'amount': amount,
        'wallet_id': walletId,
        'to_wallet_id': toWalletId,
        'category': category,
        'note': note,
        'date': date,
        'code': code,
        'created_at': createdAt,
        'source_package': sourcePackage,
        'source_hash': sourceHash,
        'created_by': createdBy,
      };
}
