// Registry pola dokumen struk + saran kategori dari isi struk.
//
// File SENGAJA tanpa import supaya bisa diverifikasi via `dart` murni.
// Satu pintu: [detectReceiptKind] untuk jenis dokumen,
// [suggestReceiptCategory] untuk kategori (hanya yang ada di daftar).
//
// Prioritas saran: merchant cocok pola dulu, lalu alias nama barang.
// Kategori yang tak ada di [categories] tak pernah disarankan.

/// Jenis dokumen struk.
enum ReceiptDocKind { minimarket, dining, generic }

/// Satu pola: jenis + keyword merchant + kategori bila merchant cocok.
class ReceiptDocPattern {
  final ReceiptDocKind kind;
  final List<String> merchantKeys;
  final String category;
  const ReceiptDocPattern(this.kind, this.merchantKeys, this.category);
}

/// Registry pola (tambah di sini untuk merchant baru, tanpa ubah logika).
const kReceiptDocPatterns = [
  ReceiptDocPattern(
    ReceiptDocKind.minimarket,
    ['indomaret', 'indomarco', 'alfamart', 'alfamidi'],
    'Belanja',
  ),
  ReceiptDocPattern(
    ReceiptDocKind.dining,
    [
      'point coffee',
      'kopi kenangan',
      'janji jiwa',
      'fore coffee',
      'cafe',
      'resto',
      'rumah makan',
      'warteg',
      'angkringan',
    ],
    'Makanan',
  ),
  ReceiptDocPattern(
    ReceiptDocKind.generic,
    ['apotek', 'kimia farma'],
    'Kesehatan',
  ),
];

/// Alias nama barang -> kategori (di luar merchant).
const _itemAlias = <String, String>{
  'kopi': 'Makanan',
  'coffee': 'Makanan',
  'latte': 'Makanan',
  'cappuccino': 'Makanan',
  'nasi': 'Makanan',
  'ayam': 'Makanan',
  'mie': 'Makanan',
  'makan': 'Makanan',
  'minum': 'Makanan',
  'jajan': 'Makanan',
  'bensin': 'Transportasi',
  'parkir': 'Transportasi',
  'tol': 'Transportasi',
  'ojek': 'Transportasi',
  'pulsa': 'Pulsa & Internet',
  'kuota': 'Pulsa & Internet',
  'internet': 'Pulsa & Internet',
  'obat': 'Kesehatan',
  'vitamin': 'Kesehatan',
  'buku': 'Pendidikan',
  'pulpen': 'Pendidikan',
};

/// Teks mentah -> jenis dokumen (pola pertama yang cocok menang).
ReceiptDocKind detectReceiptKind(String raw) {
  final t = raw.toLowerCase();
  for (final p in kReceiptDocPatterns) {
    if (p.merchantKeys.any((k) => t.contains(k))) return p.kind;
  }
  return ReceiptDocKind.generic;
}

/// Saran kategori atau null (tak ada yang cocok / tak ada di daftar).
String? suggestReceiptCategory({
  String? merchant,
  List<String> items = const [],
  String? raw,
  required List<String> categories,
}) {
  final canon = <String, String>{
    for (final c in categories) c.trim().toLowerCase(): c,
  };
  canon.remove('');
  String? pick(String name) => canon[name.trim().toLowerCase()];

  final m = (merchant ?? '').toLowerCase();
  if (m.isNotEmpty) {
    for (final p in kReceiptDocPatterns) {
      if (p.merchantKeys.any((k) => m.contains(k))) {
        final hit = pick(p.category);
        if (hit != null) return hit;
      }
    }
    final direct = pick(m);
    if (direct != null) return direct;
  }
  final hay = '${items.join(' ')} ${raw ?? ''}'.toLowerCase();
  String? best;
  var bestLen = 0;
  _itemAlias.forEach((alias, cat) {
    if (hay.contains(alias) && alias.length > bestLen) {
      final hit = pick(cat);
      if (hit != null) {
        best = hit;
        bestLen = alias.length;
      }
    }
  });
  return best;
}
