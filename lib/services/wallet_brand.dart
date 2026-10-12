// Logo brand dompet: monogram + warna brand dari keyword nama.
// Murni Dart. Tak cocok (Kas, nama umum) = null → fallback ikon tipe.
// Cocok pakai batas kata supaya "Jagoan" tak jadi "Jago".
class WalletBrand {
  final String short;
  final int argb;
  const WalletBrand(this.short, this.argb);
}

const _brands = <List<dynamic>>[
  ['bca', 'BCA', 0xFF1E4DB7],
  ['bri', 'BRI', 0xFF00529C],
  ['bni', 'BNI', 0xFFED761D],
  ['btn', 'BTN', 0xFF004A8F],
  ['mandiri', 'MDR', 0xFF002D62],
  ['livin', 'MDR', 0xFF002D62],
  ['dana', 'DN', 0xFF108EE9],
  ['ovo', 'OVO', 0xFF4C1D95],
  ['gopay', 'GP', 0xFF00AED6],
  ['gojek', 'GP', 0xFF00AED6],
  ['shopee', 'SP', 0xFFEE4D2D],
  ['shopeepay', 'SP', 0xFFEE4D2D],
  ['seabank', 'SB', 0xFF43A047],
  ['jenius', 'JN', 0xFF00A0DF],
  ['jago', 'JG', 0xFF7B3FA0],
  ['blu', 'BLU', 0xFF008FD3],
  ['cimb', 'CIMB', 0xFFC8102E],
  ['niaga', 'CIMB', 0xFFC8102E],
  ['octo', 'CIMB', 0xFFC8102E],
  ['isaku', 'IS', 0xFF6A1B9A],
  ['hana', 'HANA', 0xFF00857C],
];

WalletBrand? brandForWallet(String? name) {
  final n = (name ?? '').trim().toLowerCase();
  if (n.isEmpty) return null;
  for (final b in _brands) {
    final kw = b[0] as String;
    final re = RegExp('(^|[^a-z])' + RegExp.escape(kw) + r'([^a-z]|$)');
    if (re.hasMatch(n)) {
      return WalletBrand(b[1] as String, b[2] as int);
    }
  }
  return null;
}
