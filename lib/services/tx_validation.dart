String? validateTxInput({
  required double amount,
  required String? walletId,
  required String type,
  String? toWalletId,
}) {
  if (amount <= 0) return 'Nominal harus lebih dari 0';
  if (walletId == null) return 'Pilih dompet';
  if (type == 'transfer') {
    if (toWalletId == null) return 'Pilih dompet tujuan';
    if (toWalletId == walletId) return 'Dompet tujuan sama dengan asal';
  }
  return null;
}
