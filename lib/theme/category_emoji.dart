// Emoji semantik per kategori (brief §3.3, keputusan designer).
// Alasan: penanda makna instan (makanan = 🍜), bukan dekorasi (R-04).
// Fallback 📦 bila tak dikenal. Tanpa import (murni, testable).

const _emojiMap = <String, String>{
  'makan': '🍜',
  'makanan': '🍜',
  'food': '🍜',
  'kuliner': '🍜',
  'jajan': '🍜',
  'transport': '⛽',
  'transportasi': '⛽',
  'bensin': '⛽',
  'bahan bakar': '⛽',
  'belanja': '🛒',
  'tagihan': '🧾',
  'listrik': '🧾',
  'air': '🧾',
  'kesehatan': '💊',
  'obat': '💊',
  'pendidikan': '🎓',
  'sekolah': '🎓',
  'hiburan': '🎮',
  'pulsa': '📶',
  'internet': '📶',
  'tabungan': '💰',
  'savings': '💰',
  'nabung': '💰',
  'transfer': '💸',
  'sewa': '🏠',
  'kontrakan': '🏠',
  'rumah': '🏠',
  'gaji': '💵',
  'insentif': '💵',
};

/// Emoji untuk nama kategori (cocok lapis-atas, case-insensitive).
String categoryEmoji(String category) {
  final t = category.trim().toLowerCase();
  if (t.isEmpty) return '📦';
  final hit = _emojiMap[t];
  if (hit != null) return hit;
  for (final e in _emojiMap.entries) {
    if (t.contains(e.key)) return e.value;
  }
  return '📦';
}
