class WalletBalance {
  final String walletId;
  final double balance;
  const WalletBalance({required this.walletId, required this.balance});

  factory WalletBalance.fromMap(Map<String, dynamic> m) {
    final raw = m['balance'];
    final double bal;
    if (raw is num) {
      bal = raw.toDouble();
    } else if (raw is String) {
      bal = double.tryParse(raw) ?? 0;
    } else {
      bal = 0;
    }
    return WalletBalance(
      walletId: m['wallet_id'].toString(),
      balance: bal,
    );
  }
}
