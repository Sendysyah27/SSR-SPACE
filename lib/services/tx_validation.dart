import 'package:ssr_space/utils/strings.dart';

/// Field penyebab gagal validasi (untuk error berlabuh di form).
enum TxInvalid { amount, wallet, toWallet, sameWallet }

/// Versi field-keyed dari validasi (murni, bisa di-test).
TxInvalid? validateTxField({
  required double amount,
  required String? walletId,
  required String type,
  String? toWalletId,
}) {
  if (amount <= 0) return TxInvalid.amount;
  if (walletId == null) return TxInvalid.wallet;
  if (type == 'transfer') {
    if (toWalletId == null) return TxInvalid.toWallet;
    if (toWalletId == walletId) return TxInvalid.sameWallet;
  }
  return null;
}

String? validateTxInput({
  required double amount,
  required String? walletId,
  required String type,
  String? toWalletId,
}) {
  switch (validateTxField(
    amount: amount,
    walletId: walletId,
    type: type,
    toWalletId: toWalletId,
  )) {
    case TxInvalid.amount:
      return tr('txv_amount');
    case TxInvalid.wallet:
      return tr('txv_wallet');
    case TxInvalid.toWallet:
      return tr('txv_towallet');
    case TxInvalid.sameWallet:
      return tr('txv_same');
    case null:
      return null;
  }
}
