import 'package:ssr_space/models/transaction.dart';

/// True bila transaksi tak menyentuh dompet mana pun sehingga
/// tidak masuk hitungan saldo `wallet_balance`:
/// - in/out: `wallet_id` null.
/// - transfer: salah satu sisi (`wallet_id` / `to_wallet_id`) null.
bool hasNoWallet(SaasTransaction t) {
  if (t.type == 'transfer') {
    return t.walletId == null || t.toWalletId == null;
  }
  return t.walletId == null;
}

/// Jumlah nominal transaksi tanpa dompet (untuk banner peringatan).
double noWalletTotal(List<SaasTransaction> txs) {
  var sum = 0.0;
  for (final t in txs) {
    if (hasNoWallet(t)) sum += t.amount;
  }
  return sum;
}
