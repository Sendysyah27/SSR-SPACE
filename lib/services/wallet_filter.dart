import '../models/transaction.dart';

/// Filter list ke satu dompet. Null atau kosong berarti semua.
/// Transfer ikut bila walletId atau toWalletId cocok. Kembalikan salinan.
List<SaasTransaction> filterByWallet(
  List<SaasTransaction> items,
  String? walletId,
) {
  if (walletId == null || walletId.isEmpty) {
    return List<SaasTransaction>.of(items);
  }
  return items.where((t) {
    return t.walletId == walletId || t.toWalletId == walletId;
  }).toList();
}
