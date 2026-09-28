// Ketik cepat: "makan siang 35rb" -> transaksi terstruktur.
//
// File SENGAJA tanpa import apa pun supaya bisa diverifikasi via `dart`
// murni di Termux. UI (TxInputSheet) hanya memanggil parseQuickInput;
// validasi akhir tetap di TransactionService saat simpan.

/// Hasil urai ketik cepat (semua nominal dalam IDR).
class QuickInput {
  final double amount;
  final String type;
  final String? category;
  final String? walletName;
  final String note;
  const QuickInput({
    required this.amount,
    required this.type,
    this.category,
    this.walletName,
    required this.note,
  });
}

final _amtRe = RegExp(
  r'(\d[\d.,]*)\s*(rb|ribu|jt|juta|k(?![a-z]))?',
  caseSensitive: false,
);

double? _amountValue(String num, String? unit) {
  var n = num.replaceAll(' ', '');
  final u = (unit ?? '').toLowerCase();
  double mult = 1;
  if (u == 'jt' || u == 'juta') {
    mult = 1000000;
  } else if (u == 'rb' || u == 'ribu' || u == 'k') {
    mult = 1000;
  }
  final hasDot = n.contains('.');
  final hasComma = n.contains(',');
  String norm;
  if (u.isNotEmpty) {
    norm = n.replaceAll(',', '.');
  } else if (hasDot && hasComma) {
    norm = n.lastIndexOf('.') > n.lastIndexOf(',')
        ? n.replaceAll(',', '')
        : n.replaceAll('.', '').replaceAll(',', '.');
  } else if (hasComma) {
    final parts = n.split(',');
    norm = parts.length == 2 && parts[1].length <= 2
        ? '${parts[0]}.${parts[1]}'
        : n.replaceAll(',', '');
  } else if (hasDot) {
    final parts = n.split('.');
    final thou =
        parts.length > 1 && parts.skip(1).every((p) => p.length == 3);
    norm = thou ? n.replaceAll('.', '') : n;
  } else {
    norm = n;
  }
  final v = double.tryParse(norm);
  if (v == null || v <= 0) return null;
  return v * mult;
}

bool _word(String t, String w) =>
    RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(t);

const _tfKw = ['transfer', 'tf', 'kirim', 'mutasi'];
const _inKw = [
  'masuk',
  'terima',
  'diterima',
  'menerima',
  'dapat',
  'dapet',
  'gaji',
  'bonus',
  'pemasukan',
  'income',
  'top up',
  'topup',
  'isi saldo',
];

String _quickType(String t) {
  final inHit = _inKw.any((k) => _word(t, k));
  if (inHit) return 'in';
  final tfHit = _tfKw.any((k) => _word(t, k));
  if (tfHit) return 'transfer';
  return 'out';
}

/// Alias kata -> nama kategori kanonis (dipakai bila nama tak disebut
/// langsung; hanya bila target ada di daftar kategori).
const _catAlias = <String, String>{
  'makan': 'Makanan',
  'makanan': 'Makanan',
  'minum': 'Makanan',
  'kuliner': 'Makanan',
  'jajan': 'Makanan',
  'transport': 'Transportasi',
  'transportasi': 'Transportasi',
  'bensin': 'Transportasi',
  'parkir': 'Transportasi',
  'ojek': 'Transportasi',
  'tol': 'Transportasi',
  'belanja': 'Belanja',
  'tagihan': 'Tagihan',
  'listrik': 'Tagihan',
  'air': 'Tagihan',
  'pulsa': 'Pulsa & Internet',
  'internet': 'Pulsa & Internet',
  'wifi': 'Pulsa & Internet',
  'kuota': 'Pulsa & Internet',
  'sehat': 'Kesehatan',
  'kesehatan': 'Kesehatan',
  'obat': 'Kesehatan',
  'dokter': 'Kesehatan',
  'sekolah': 'Pendidikan',
  'pendidikan': 'Pendidikan',
  'kuliah': 'Pendidikan',
  'kursus': 'Pendidikan',
  'buku': 'Pendidikan',
  'hiburan': 'Hiburan',
  'film': 'Hiburan',
  'game': 'Hiburan',
  'musik': 'Hiburan',
  'tabungan': 'Tabungan',
  'menabung': 'Tabungan',
  'nabung': 'Tabungan',
  'saving': 'Tabungan',
  'lainnya': 'Lainnya',
};

String? _matchCat(String t, List<String> cats) {
  final canon = <String, String>{
    for (final c in cats) c.trim().toLowerCase(): c,
  };
  canon.remove('');
  var best;
  String? bestName;
  var bestLen = 0;
  canon.forEach((low, name) {
    if (t.contains(low) && low.length > bestLen) {
      best = low;
      bestName = name;
      bestLen = low.length;
    }
  });
  if (bestName != null) return bestName;
  for (final e in _catAlias.entries) {
    if (_word(t, e.key)) {
      final hit = canon[e.value.toLowerCase()];
      if (hit != null) return hit;
    }
  }
  return null;
}

String? _matchWallet(String t, List<String> wallets) {
  String? best;
  var bestIdx = 1 << 30;
  var bestLen = 0;
  for (final w in wallets) {
    final low = w.trim().toLowerCase();
    if (low.isEmpty) continue;
    final idx = t.indexOf(low);
    if (idx < 0) continue;
    if (idx < bestIdx || (idx == bestIdx && low.length > bestLen)) {
      best = w;
      bestIdx = idx;
      bestLen = low.length;
    }
  }
  return best;
}

/// Urai teks bebas. Null bila tak ada nominal valid. Tak pernah throw
/// untuk input aneh (kembalikan null).
QuickInput? parseQuickInput(
  String text, {
  required List<String> categories,
  required List<String> wallets,
}) {
  final t = text.toLowerCase();
  RegExpMatch? hit;
  double? amount;
  for (final m in _amtRe.allMatches(t)) {
    final v = _amountValue(m.group(1)!, m.group(2));
    if (v != null) {
      hit = m;
      amount = v;
      break;
    }
  }
  if (hit == null || amount == null) return null;
  final note = text
      .replaceFirst(hit.group(0)!, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return QuickInput(
    amount: amount,
    type: _quickType(t),
    category: _matchCat(t, categories),
    walletName: _matchWallet(t, wallets),
    note: note,
  );
}
