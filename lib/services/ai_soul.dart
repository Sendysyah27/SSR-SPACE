// Charter + memori AI Chat SSR SPACE. Hanya dart:core + dart:convert
// (tanpa package Flutter/plugin) agar testable via `dart` murni.
// Soul = kepribadian ringkas; memory = fakta per user (maks 20, prefs
// di ai_memory.dart). Aksi transaksi SELALU lewat konfirmasi user
// (blok tx -> tombol Jalankan).
import 'dart:convert';

/// Kepribadian: ringkas, Indonesia, santai tapi akurat soal uang.
const aiSoul = 'Kamu asisten keuangan SSR SPACE: ramah, ringkas, '
    'Bahasa Indonesia santai. Jawab singkat (maks 5 kalimat kecuali '
    'diminta panjang). Soal uang: teliti, jangan karang angka. '
    'Untuk mencatat transaksi, tulis blok ```tx {"type":"out|in", '
    '"amount":angka, "category":"...", "note":"..."}``` lalu minta '
    'user ketuk Jalankan. Untuk mengingat fakta user, tulis blok '
    '```ingat fakta singkat```. Jangan pernah mengeksekusi apapun '
    'sendiri.';

const aiMemoryCap = 20;

/// Blok konteks disuntik ke tiap prompt: soul + fakta user.
String aiContextBlock(List<String> memory) {
  final buf = StringBuffer(aiSoul);
  if (memory.isNotEmpty) {
    buf.write('\nFakta tentang user:');
    for (final m in memory.take(aiMemoryCap)) {
      buf.write('\n- $m');
    }
  }
  return buf.toString();
}

/// Ambil semua isi blok ```ingat ...``` dari balasan AI.
List<String> parseIngatBlocks(String text) {
  final out = <String>[];
  final re = RegExp(r'```ingat\s+(.+?)```', dotAll: true);
  for (final m in re.allMatches(text)) {
    final v = m.group(1)!.trim();
    if (v.isNotEmpty && v.length <= 200) out.add(v);
  }
  return out;
}

class TxDraft {
  final String type;
  final double amount;
  final String? category;
  final String? note;
  const TxDraft({
    required this.type,
    required this.amount,
    this.category,
    this.note,
  });
}

/// Ambil JSON blok ```tx {...}``` pertama, atau null.
String? parseTxBlock(String text) {
  final m =
      RegExp(r'```tx\s+(\{.+?\})```', dotAll: true).firstMatch(text);
  return m?.group(1);
}

/// JSON tx -> field aman (gagal = null, tak pernah throw).
TxDraft? parseTxDraft(String? jsonText) {
  if (jsonText == null) return null;
  try {
    final m = jsonDecode(jsonText);
    if (m is! Map) return null;
    final type = m['type'];
    final amount = m['amount'];
    if (type != 'in' && type != 'out') return null;
    final n = amount is num
        ? amount.toDouble()
        : double.tryParse('${m['amount']}');
    if (n == null || n <= 0) return null;
    String? str(dynamic v) =>
        v is String && v.trim().isNotEmpty ? v.trim() : null;
    return TxDraft(
      type: type,
      amount: n,
      category: str(m['category']),
      note: str(m['note']),
    );
  } catch (_) {
    return null;
  }
}
