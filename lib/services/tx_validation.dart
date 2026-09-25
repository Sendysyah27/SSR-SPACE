import 'package:ssr_space/utils/strings.dart';

String? validateTxInput({
  required double amount,
  required String? walletId,
  required String type,
  String? toWalletId,
}) {
  if (amount <= 0) return tr('txv_amount');
  if (walletId == null) return tr('txv_wallet');
  if (type == 'transfer') {
    if (toWalletId == null) return tr('txv_towallet');
    if (toWalletId == walletId) return tr('txv_same');
  }
  return null;
}
