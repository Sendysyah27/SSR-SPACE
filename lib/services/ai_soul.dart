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
    'user ketuk Jalankan. Untuk tagihan rutin: ```tagihan '
    '{"label":"...", "amount":angka, "category":"..."}```. Untuk '
    'target budget: ```budget {"category":"...", "limit":angka}```. '
    'Untuk mengingat fakta user, tulis blok '
    '```ingat fakta singkat```. Jangan pernah mengeksekusi apapun '
    'sendiri.';

const aiMemoryCap = 20;
const aiHistoryTurns = 10;
const aiHistoryChars = 300;

/// Blok riwayat chat sesi ini untuk konteks tiap request (maks 10
/// turn terakhir, teks dipadatkan). Murni agar testable.
String chatHistoryBlock(List<({bool mine, String text})> history) {
  if (history.isEmpty) return '';
  final turns = history.length <= aiHistoryTurns
      ? history
      : history.sublist(history.length - aiHistoryTurns);
  final buf = StringBuffer('Riwayat chat sesi ini:\n');
  for (final t in turns) {
    var txt = t.text.replaceAll('\n', ' ').trim();
    if (txt.length > aiHistoryChars) {
      txt = txt.substring(0, aiHistoryChars);
    }
    buf.write(t.mine ? 'User: ' : 'AI: ');
    buf.writeln(txt);
  }
  return buf.toString();
}

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

class BillDraft {
  final String label;
  final double amount;
  final String? category;
  const BillDraft({required this.label, required this.amount, this.category});
}

class BudgetDraft {
  final String category;
  final double limit;
  const BudgetDraft({required this.category, required this.limit});
}

double? _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

String? _str(dynamic v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

/// JSON tagihan -> [BillDraft] atau null (tak pernah throw).
BillDraft? parseBillDraft(String? jsonText) {
  if (jsonText == null) return null;
  try {
    final m = jsonDecode(jsonText);
    if (m is! Map) return null;
    final label = _str(m['label']);
    final n = _num(m['amount']);
    if (label == null || n == null || n <= 0) return null;
    return BillDraft(label: label, amount: n, category: _str(m['category']));
  } catch (_) {
    return null;
  }
}

/// JSON budget -> [BudgetDraft] atau null (tak pernah throw).
BudgetDraft? parseBudgetDraft(String? jsonText) {
  if (jsonText == null) return null;
  try {
    final m = jsonDecode(jsonText);
    if (m is! Map) return null;
    final category = _str(m['category']);
    final n = _num(m['limit']);
    if (category == null || n == null || n <= 0) return null;
    return BudgetDraft(category: category, limit: n);
  } catch (_) {
    return null;
  }
}

/// Ambil JSON blok ```tx {...}``` pertama, atau null.
String? parseTxBlock(String text) {
  final m =
      RegExp(r'```tx\s+(\{.+?\})```', dotAll: true).firstMatch(text);
  return m?.group(1);
}

/// Ambil JSON blok ```tagihan {...}``` / ```budget {...}``` pertama.
String? parseNamedBlock(String text, String name) {
  final m = RegExp('```$name\\s+(\\{.+?\\})```', dotAll: true)
      .firstMatch(text);
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
