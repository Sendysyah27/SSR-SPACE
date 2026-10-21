// Parser + prompt scan struk via Mang AI server.
//
// File SENGAJA hanya import dart:convert supaya murni dan mudah dites
// (`flutter test`). Uang = int (rupiah). Tidak ada log data di sini.
//
// Batch 284 tahap E: jalur receipt kini SATU parser JSON. EF
// mang-ai-chat menormalisasi keluaran model (JSON berantakan /
// format baris lama) jadi JSON ketat {merchant, date, total,
// category, items[]} sebelum diteruskan ke klien; parser format
// baris dipensiunkan. Prompt lengkap + daftar kategori dirakit EF
// dari DB; klien hanya mengirim prompt JSON ringkas tanpa kategori
// (scanReceiptJsonPrompt).

import 'dart:convert';

/// Satu baris item dari hasil vision (tanpa OCR): nama + qty + harga.
/// Uang = int (rupiah). Bounding box TIDAK diminta: model teks via
/// OpenCode chat completions tidak bisa mengembalikan koordinat piksel
/// yang dapat diandalkan (hasilnya halusinasi bila dipaksa).
class ReceiptScanItem {
  /// Nama produk sesuai tertulis di struk.
  final String name;
  /// Jumlah pcs (default 1 bila tak disebut).
  final int qty;
  /// Harga TOTAL baris ini (qty x harga satuan), rupiah, integer >= 0.
  final int price;
  const ReceiptScanItem({required this.name, this.qty = 1, required this.price});
}

/// Hasil scan struk yang lolos validasi ketat.
class ReceiptScanResult {
  /// Nama gerai (opsional).
  final String? merchant;

  /// Tanggal transaksi, format YYYY-MM-DD, tanggal kalender valid.
  final String date;

  /// Grand total yang dibayar (setelah diskon), rupiah, integer > 0.
  final int total;

  /// Kategori dalam bentuk kanonis dari daftar kategori app.
  final String category;

  /// Baris item/produk (maks 100; selebihnya dihitung di [truncatedItems]).
  /// Bisa kosong bila model tidak mengembalikannya; hasil tetap valid.
  final List<ReceiptScanItem> items;

  /// Jumlah item valid yang terpotong karena batas 100.
  final int truncatedItems;

  const ReceiptScanResult({
    this.merchant,
    required this.date,
    required this.total,
    required this.category,
    this.items = const [],
    this.truncatedItems = 0,
  });
}

/// Batas item yang disimpan terstruktur (di atasnya disingkat).
const scanItemCap = 100;

/// System prompt ringkas scan struk sisi klien (batch 284 tahap E):
/// TANPA daftar kategori — kategori dibaca & prompt lengkap dirakit
/// EF dari DB (prompt server memakai format baris + normalisasi
/// JSON di EF). Prompt klien ini jaring pengaman kompatibilitas:
/// EF lama meneruskannya apa adanya (model tetap diminta JSON
/// ketat), EF baru menggantinya dengan prompt server.
String scanReceiptJsonPrompt() {
  return 'Kamu pengurai struk belanja Indonesia. Baca struk dengan teliti '
      'dari atas sampai bawah. Balas HANYA JSON valid tanpa markdown, '
      'tanpa penjelasan, dengan format persis: '
      '{"merchant":"Nama Gerai","date":"YYYY-MM-DD","total":16000,'
      '"category":"Makanan","items":[{"name":"Produk","qty":1,"price":1700}]}. '
      'Aturan: total = GRAND TOTAL yang dibayar (SETELAH diskon), integer '
      'murni rupiah; category = nama kategori pengeluaran yang paling '
      'sesuai; items = SEMUA baris produk dari atas sampai bawah, lengkap '
      'jangan diringkas, price = harga TOTAL baris itu (qty x harga '
      'satuan) dalam rupiah integer; abaikan baris subtotal/pajak/diskon/'
      'pembulatan/tunai/kembalian/metode bayar (bukan produk); jangan '
      'karang angka bila ragu; jangan pakai tool.';
}

/// Ekstrak substring objek JSON pertama yang kurungnya seimbang
/// (sadar string) dari [s]; null bila tak ada / tak seimbang.
String? _extractJsonObject(String s) {
  final start = s.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inStr = false;
  var esc = false;
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
        if (depth == 0) return s.substring(start, i + 1);
      }
    }
  }
  return null;
}

/// JSON mentah model -> [ReceiptScanResult] atau null bila tak valid.
/// Parser TUNGGAL jalur receipt sejak tahap E (keluaran EF sudah
/// dinormalisasi JSON ketat; ekstraksi objek seimbang jadi jaring
/// pengaman untuk bungkus prosa/fence sisa).
///
/// Validasi ketat:
/// - total HARUS int > 0 (tolak 0, negatif, double, string)
/// - date HARUS YYYY-MM-DD dan tanggal kalender valid
/// - category HARUS cocok (tak sensitif huruf-besar) dengan [categories]
/// - merchant opsional
/// - items opsional; tiap item: name non-kosong, price int >= 0,
///   qty int > 0 (default 1). Item tak valid dilewati.
ReceiptScanResult? parseReceiptScanJson(String raw, List<String> categories) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  s = s.replaceAll(RegExp(r'^```(json)?\s*'), '');
  s = s.replaceAll(RegExp(r'\s*```$'), '');
  dynamic decoded;
  try {
    decoded = jsonDecode(s);
  } catch (_) {
    final inner = _extractJsonObject(s);
    if (inner == null) return null;
    try {
      decoded = jsonDecode(inner);
    } catch (_) {
      return null;
    }
  }
  if (decoded is! Map) return null;
  final m = Map<String, dynamic>.from(decoded);

  // total: integer murni > 0.
  final tv = m['total'];
  if (tv is! int || tv <= 0) return null;

  // date: format + tanggal kalender valid (cek round-trip).
  final dv = m['date'];
  if (dv is! String) return null;
  final ds = dv.trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(ds)) return null;
  final dt = DateTime.tryParse(ds);
  if (dt == null) return null;
  final back = '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
  if (back != ds) return null;

  // category: harus ada di daftar app (tak sensitif huruf).
  final cv = m['category'];
  if (cv is! String) return null;
  final ct = cv.trim().toLowerCase();
  if (ct.isEmpty) return null;
  String? canonical;
  for (final c in categories) {
    if (c.trim().toLowerCase() == ct) {
      canonical = c.trim();
      break;
    }
  }
  if (canonical == null || canonical.isEmpty) return null;

  // items: daftar produk, toleran (item tak valid -> dilewati).
  final scanItems = <ReceiptScanItem>[];
  var truncated = 0;
  final iv = m['items'];
  if (iv is List) {
    for (final e in iv) {
      if (e is! Map) continue;
      final im = Map<String, dynamic>.from(e);
      final nm = im['name'];
      final pr = im['price'];
      if (nm is! String || nm.trim().isEmpty) continue;
      if (pr is! int || pr < 0) continue;
      var q = 1;
      final qv = im['qty'];
      if (qv is int && qv > 0 && qv <= 10000) q = qv;
      var nmS = nm.trim();
      if (nmS.length > 120) nmS = nmS.substring(0, 120);
      if (scanItems.length >= scanItemCap) {
        truncated++;
        continue;
      }
      scanItems.add(ReceiptScanItem(name: nmS, qty: q, price: pr));
    }
  }

  // merchant: opsional.
  String? merchant;
  final mv = m['merchant'];
  if (mv is String) {
    final mt = mv.trim();
    if (mt.isNotEmpty) {
      merchant = mt.length <= 120 ? mt : mt.substring(0, 120);
    }
  }

  return ReceiptScanResult(
    merchant: merchant,
    date: ds,
    total: tv,
    category: canonical,
    items: scanItems,
    truncatedItems: truncated,
  );
}

/// Penanda catatan berisi detail struk (untuk render gaya struk di UI).
const receiptNoteMarker = '[STRUK]';

/// Hasil scan -> teks gaya struk untuk disimpan sebagai catatan transaksi.
/// Baris diawali [receiptNoteMarker] agar UI bisa render monospace.
String receiptDetailText(ReceiptScanResult r) {
  final buf = StringBuffer();
  final merch = (r.merchant ?? '').trim();
  buf.writeln('$receiptNoteMarker ${merch.isEmpty ? 'Struk belanja' : merch}');
  buf.writeln(r.date);
  buf.writeln('--------------------------------');
  var n = 0;
  for (final it in r.items) {
    n++;
    final qty = it.qty > 1 ? ' x${it.qty}' : '';
    buf.writeln('$n. ${it.name}$qty — Rp ${_rp(it.price)}');
  }
  if (r.truncatedItems > 0) {
    buf.writeln('...dan ${r.truncatedItems} item lainnya (disingkat)');
  }
  if (n == 0) {
    buf.writeln('(tidak ada rincian item)');
  }
  buf.writeln('--------------------------------');
  buf.writeln('TOTAL Rp ${_rp(r.total)}');
  return buf.toString().trimRight();
}

/// True bila catatan tampak berisi detail struk (ada penanda).
bool isReceiptDetailNote(String? note) =>
    (note ?? '').trimLeft().startsWith(receiptNoteMarker);

/// Format ribuan ala Indonesia: 115500 -> "115.500". Murni Dart.
String _rp(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}
