// Prompt + normalizer jalur AI 9router lokal (OpenAI-compatible).
//
// Cermin sisi-klien dari `supabase/functions/mang-ai-chat/index.ts`
// (batch 284 tahap E). Di jalur server, EF yang merakit prompt receipt
// dan menormalisasi keluaran model jadi JSON ketat. Di jalur 9router
// tidak ada EF, jadi pekerjaan itu dipindah ke sini.
//
// File SENGAJA hanya import dart:convert supaya murni: bisa diverifikasi
// dengan `dart --enable-asserts` / `flutter test` tanpa plugin.
// Uang = int rupiah. Tidak ada log data user di sini.

import 'dart:convert';

/// Kategori bawaan app (sama persis dengan `DEFAULT_RECEIPT_CATEGORIES`
/// di EF mang-ai-chat).
const defaultReceiptCategories = <String>[
  'Makanan',
  'Transportasi',
  'Belanja',
  'Tagihan',
  'Kesehatan',
  'Pendidikan',
  'Hiburan',
  'Pulsa & Internet',
  'Tabungan',
  'Lainnya',
];

/// Batas item yang disimpan normalizer (sama dengan EF).
const nineReceiptItemCap = 100;

/// Gabung kategori bawaan + kategori milik user (lapis atas, tanpa
/// duplikat, maks 20) — cermin `receiptCategories` EF.
List<String> receiptCategoriesFor(Iterable<String> extra) {
  final out = <String>[...defaultReceiptCategories];
  for (final raw in extra) {
    final top = raw.split('>').first.trim();
    if (top.isEmpty) continue;
    if (out.any((x) => x.toLowerCase() == top.toLowerCase())) continue;
    out.add(top);
    if (out.length >= 20) break;
  }
  return out;
}

/// System prompt receipt format baris — cermin `receiptSystemPrompt` EF.
/// Format baris dipakai (bukan JSON) karena terbukti lebih robus untuk
/// LLM; normalizer di bawah yang mengubahnya jadi JSON ketat.
String receiptSystemPrompt(List<String> categories) {
  final cats = categories
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .join(', ');
  return 'Kamu pengurai struk belanja Indonesia. Baca gambar struk dengan '
      'teliti dari atas sampai bawah. Balas HANYA teks dengan format persis '
      'seperti contoh ini, tanpa markdown, tanpa penjelasan, tanpa teks '
      'lain:\n'
      'MERCHANT: Nama Gerai\n'
      'DATE: 2026-09-08\n'
      'TOTAL: 16000\n'
      'CATEGORY: Makanan\n'
      'ITEMS:\n'
      'Racik Bumbu Sayur Asem 33gr | 1 | 1700\n'
      'Sasa Santan Kelapa Cair 65ml | 1 | 4500\n'
      'Aturan:\n'
      '- MERCHANT: nama gerai, atau kosong bila tak ada.\n'
      '- DATE: tanggal transaksi format YYYY-MM-DD.\n'
      '- TOTAL: GRAND TOTAL yang dibayar (SETELAH diskon), integer murni '
      'dalam rupiah (contoh 16000).\n'
      '- CATEGORY: harus persis salah satu dari: $cats.\n'
      '- ITEMS: SEMUA baris produk dari atas sampai bawah struk, lengkap '
      'jangan diringkas. Tiap baris format persis: nama produk | jumlah pcs '
      '| harga TOTAL baris itu (qty x harga satuan) dalam rupiah integer.\n'
      '- Abaikan baris subtotal/pajak/diskon/pembulatan/tunai/kembalian/'
      'metode bayar (bukan produk).\n'
      '- Jangan karang angka bila ragu; baris yang ragu boleh dilewati.\n'
      '- Jangan pakai tool.';
}

/// Tanggal `YYYY-MM-DD` yang benar-benar ada di kalender.
bool _isValidYmd(String s) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return false;
  final y = int.tryParse(s.substring(0, 4));
  final mo = int.tryParse(s.substring(5, 7));
  final d = int.tryParse(s.substring(8, 10));
  if (y == null || mo == null || d == null) return false;
  final dt = DateTime.utc(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return false;
  return true;
}

/// Angka bulat non-negatif dari nilai JSON (int / double utuh).
int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is double && v.isFinite && v == v.roundToDouble()) return v.toInt();
  return null;
}

/// Ekstrak objek JSON pertama yang valid dari teks (utuh / fence /
/// kurung seimbang sadar-string) — cermin `extractReceiptJson` EF.
Map<String, dynamic>? extractReceiptJson(String t) {
  final s = t.trim();
  if (s.isEmpty) return null;
  Map<String, dynamic>? ok(String txt) {
    try {
      final j = jsonDecode(txt);
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {
      // bukan JSON utuh: lanjut ke strategi berikutnya.
    }
    return null;
  }

  final direct = ok(s);
  if (direct != null) return direct;

  final fence = RegExp(r'```(?:json)?\s*(\{[\s\S]*\})\s*```').firstMatch(s);
  if (fence != null) {
    final inner = ok((fence.group(1) ?? '').trim());
    if (inner != null) return inner;
  }

  final start = s.indexOf('{');
  if (start >= 0) {
    var depth = 0;
    var inStr = false;
    var esc = false;
    var end = -1;
    for (var i = start; i < s.length; i++) {
      final c = s[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (c == '\\') {
          esc = true;
        } else if (c == '"') {
          inStr = false;
        }
      } else {
        if (c == '"') {
          inStr = true;
        } else if (c == '{') {
          depth++;
        } else if (c == '}') {
          depth--;
          if (depth == 0) {
            end = i;
            break;
          }
        }
      }
    }
    if (end > start) {
      final inner = ok(s.substring(start, end + 1));
      if (inner != null) return inner;
    }
  }
  return null;
}

/// Parser format baris MERCHANT/DATE/TOTAL/CATEGORY + ITEMS —
/// cermin `parseReceiptLines` EF.
Map<String, dynamic>? parseReceiptLines(String t) {
  var s = t.trim();
  if (s.isEmpty) return null;
  s = s.replaceFirst(RegExp(r'^```(\w+)?\s*'), '');
  s = s.replaceFirst(RegExp(r'\s*```$'), '');
  final lines = s
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return null;

  String? merchant;
  String? dateStr;
  int? total;
  String? categoryRaw;
  var i = 0;
  for (; i < lines.length; i++) {
    final l = lines[i];
    if (l.toUpperCase() == 'ITEMS:') {
      i++;
      break;
    }
    final colon = l.indexOf(':');
    if (colon <= 0) continue;
    final key = l.substring(0, colon).trim().toUpperCase();
    final val = l.substring(colon + 1).trim();
    switch (key) {
      case 'MERCHANT':
        merchant = val.isEmpty ? null : val;
      case 'DATE':
        dateStr = val;
      case 'TOTAL':
        final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
        total = digits.isEmpty ? null : int.tryParse(digits);
      case 'CATEGORY':
        categoryRaw = val;
    }
  }
  if (total == null || total <= 0) return null;
  if (dateStr == null || !_isValidYmd(dateStr.trim())) return null;
  final ds = dateStr.trim();
  if (categoryRaw == null || categoryRaw.trim().isEmpty) return null;

  final items = <Map<String, dynamic>>[];
  for (; i < lines.length; i++) {
    final l = lines[i];
    if (l.startsWith('...')) continue;
    final parts = l.split('|');
    if (parts.length < 3) continue;
    final priceDigits = parts.last.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final price = priceDigits.isEmpty ? null : int.tryParse(priceDigits);
    if (price == null || price < 0) continue;
    final qtyDigits = parts[parts.length - 2].trim().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    var qty = qtyDigits.isEmpty ? 1 : int.tryParse(qtyDigits);
    if (qty == null || qty <= 0 || qty > 10000) qty = 1;
    var name = parts.sublist(0, parts.length - 2).join('|').trim();
    if (name.isEmpty) continue;
    if (name.length > 120) name = name.substring(0, 120);
    if (items.length >= nineReceiptItemCap) continue;
    items.add({'name': name, 'qty': qty, 'price': price});
  }
  if (merchant != null && merchant.length > 120) {
    merchant = merchant.substring(0, 120);
  }
  return {
    'merchant': merchant,
    'date': ds,
    'total': total,
    'category': categoryRaw.trim(),
    'items': items,
  };
}

/// Normalisasi keluaran receipt jadi JSON ketat
/// `{merchant, date, total, category, items[]}` — cermin
/// `normalizeReceiptContract` EF. Sumber boleh JSON berantakan atau
/// format baris. Kategori dipetakan ke [categories] (tak sensitif
/// huruf); di luar daftar → 'Lainnya' (atau entri pertama).
/// Tak terparse / tak valid → teks apa adanya.
String normalizeReceiptContract(String t, List<String> categories) {
  final src = extractReceiptJson(t) ?? parseReceiptLines(t);
  if (src == null) return t;

  final total = _asInt(src['total']);
  if (total == null || total <= 0) return t;

  final dateRaw = src['date'];
  final date = dateRaw is String ? dateRaw.trim() : '';
  if (!_isValidYmd(date)) return t;

  final catRaw = src['category'];
  var category = catRaw is String ? catRaw.trim() : '';
  if (category.isEmpty) return t;
  String? match;
  for (final c in categories) {
    if (c.toLowerCase() == category.toLowerCase()) {
      match = c;
      break;
    }
  }
  if (match != null) {
    category = match;
  } else if (categories.isNotEmpty) {
    category = categories.contains('Lainnya') ? 'Lainnya' : categories.first;
  }

  final items = <Map<String, dynamic>>[];
  final rawItems = src['items'];
  if (rawItems is List) {
    for (final e in rawItems) {
      if (e is! Map) continue;
      final nm = e['name'];
      final pr = _asInt(e['price']);
      if (nm is! String || nm.trim().isEmpty) continue;
      if (pr == null || pr < 0) continue;
      var q = 1;
      final qv = e['qty'];
      final qi = qv is int ? qv : null;
      if (qi != null && qi > 0 && qi <= 10000) q = qi;
      var name = nm.trim();
      if (name.length > 120) name = name.substring(0, 120);
      items.add({'name': name, 'qty': q, 'price': pr});
      if (items.length >= nineReceiptItemCap) break;
    }
  }

  final mRaw = src['merchant'];
  final merchant = (mRaw is String && mRaw.trim().isNotEmpty)
      ? (mRaw.trim().length <= 120
            ? mRaw.trim()
            : mRaw.trim().substring(0, 120))
      : null;

  return jsonEncode({
    'merchant': merchant,
    'date': date,
    'total': total,
    'category': category,
    'items': items,
  });
}

/// Ekstrak kontrak chat `{"reply": ...}` dari teks (utuh / fence /
/// kemunculan terakhir `{"reply"`) — cermin `extractContractJson` EF.
Map<String, dynamic>? _extractChatContract(String t) {
  final s = t.trim();
  if (s.isEmpty) return null;
  Map<String, dynamic>? ok(String txt) {
    try {
      final j = jsonDecode(txt);
      if (j is Map) {
        final reply = j['reply'];
        if (reply is String && reply.trim().isNotEmpty) {
          return Map<String, dynamic>.from(j);
        }
      }
    } catch (_) {
      // bukan JSON kontrak: lanjut.
    }
    return null;
  }

  final direct = ok(s);
  if (direct != null) return direct;

  final fence = RegExp(r'```(?:json)?\s*(\{[\s\S]*\})\s*```').firstMatch(s);
  if (fence != null) {
    final inner = ok((fence.group(1) ?? '').trim());
    if (inner != null) return inner;
  }

  var idx = s.lastIndexOf('{"reply"');
  while (idx >= 0) {
    var depth = 0;
    var inStr = false;
    var esc = false;
    var end = -1;
    for (var i = idx; i < s.length; i++) {
      final c = s[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (c == '\\') {
          esc = true;
        } else if (c == '"') {
          inStr = false;
        }
      } else {
        if (c == '"') {
          inStr = true;
        } else if (c == '{') {
          depth++;
        } else if (c == '}') {
          depth--;
          if (depth == 0) {
            end = i;
            break;
          }
        }
      }
    }
    if (end > idx) {
      final inner = ok(s.substring(idx, end + 1));
      if (inner != null) return inner;
    }
    idx = idx > 0 ? s.lastIndexOf('{"reply"', idx - 1) : -1;
  }
  return null;
}

/// Normalisasi jawaban chat ke kontrak `{"reply","action"}` — cermin
/// `normalizeChatContract` EF. Model free sering membungkus JSON dengan
/// prosa/fence sehingga parser ketat klien gagal dan JSON mentah bocor
/// ke bubble user. Teks tanpa kontrak dikembalikan apa adanya.
String normalizeChatContract(String t) {
  final j = _extractChatContract(t);
  if (j == null) return t;
  final reply = (j['reply'] as String).replaceAll('**', '').trim();
  if (reply.isEmpty) return t;
  return jsonEncode({'reply': reply, 'action': j['action']});
}
