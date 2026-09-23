class SaasTransaction {
  final String id;
  final String orgId;
  final String type;
  final double amount;
  final String? walletId;
  final String? toWalletId;
  final String? category;
  final String? note;
  SaasTransaction({required this.id, required this.orgId, required this.type, required this.amount, this.walletId, this.toWalletId, this.category, this.note});
  factory SaasTransaction.fromMap(Map<String, dynamic> m) => SaasTransaction(
        id: m['id'].toString(),
        orgId: m['org_id'].toString(),
        type: (m['type'] ?? '').toString(),
        amount: (m['amount'] as num).toDouble(),
        walletId: m['wallet_id']?.toString(),
        toWalletId: m['to_wallet_id']?.toString(),
        category: m['category']?.toString(),
        note: m['note']?.toString(),
      );
}
