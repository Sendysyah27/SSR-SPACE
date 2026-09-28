// Validasi edit dompet (murni, test lokal via dart --enable-asserts).
bool isValidWalletName(String v) => v.trim().isNotEmpty;

const _kWalletTypes = {'cash', 'ewallet', 'bank', 'savings', 'investment'};

bool isKnownWalletType(String t) => _kWalletTypes.contains(t);
