// Parser + prompt scan struk via OpenCode lokal.
//
// File SENGAJA hanya import dart:convert supaya murni dan mudah dites
// (`flutter test`). Uang = int (rupiah). Tidak ada log data di sini.
//
// Format model: TEKS BARIS (bukan JSON) untuk daftar item — JSON rapuh
// untuk LLM (1 karakter salah = semua gagal). Header tetap validasi ketat,
// item toleran: baris rusak -> dilewati saja.

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

/// System prompt untuk scan struk: model HARUS membalas teks baris
/// dengan format persis, tanpa markdown, tanpa penjelasan. Dibuat di Dart
/// (bukan DEFAULT_SYSTEM Kotlin yang untuk chat).
///
/// Format baris (bukan JSON): satu karakter salah di satu baris tidak
/// menggugurkan seluruh hasil — baris rusak dilewati saja.
String scanReceiptSystemPrompt(List<String> categories) {
  final cats = categories.map((c) => c.trim()).where((c) => c.isNotEmpty).join(', ');
  return 'Kamu pengurai struk belanja Indonesia. Baca gambar struk dengan teliti '
      'dari atas sampai bawah. Balas HANYA teks dengan format persis seperti contoh '
      'ini, tanpa markdown, tanpa penjelasan, tanpa teks lain:\n'
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
      '- TOTAL: GRAND TOTAL yang dibayar (SETELAH diskon), integer murni dalam '
      'rupiah (contoh 16000).\n'
      '- CATEGORY: harus persis salah satu dari: $cats.\n'
      '- ITEMS: SEMUA baris produk dari atas sampai bawah struk, lengkap jangan '
      'diringkas. Tiap baris format persis: nama produk | jumlah pcs | harga TOTAL '
      'baris itu (qty x harga satuan) dalam rupiah integer.\n'
      '- Abaikan baris subtotal/pajak/diskon/pembulatan/tunai/kembalian/metode '
      'bayar (bukan produk).\n'
      '- Jangan karang angka bila ragu; baris yang ragu boleh dilewati.\n'
      '- Jangan pakai tool.';
}

/// Prompt varian teks-OCR (fallback bila model buta gambar).
String scanReceiptOcrPrompt(String ocrText, List<String> categories) {
  final capped = ocrText.length <= 4000 ? ocrText : ocrText.substring(0, 4000);
  return '${scanReceiptSystemPrompt(categories)}\nTEKS OCR STRUK:\n$capped';
}

/// Format baris model -> [ReceiptScanResult] atau null bila header tak valid.
///
/// Validasi ketat (header):
/// - TOTAL HARUS int > 0 (toleran format "115.500"/"Rp 115500" -> 115500)
/// - DATE HARUS YYYY-MM-DD dan tanggal kalender valid
/// - CATEGORY HARUS cocok (tak sensitif huruf-besar) dengan [categories]
/// - MERCHANT opsional
///
/// Toleran (item): tiap baris `nama | qty | harga`; baris rusak dilewati.
/// Maks [scanItemCap] item; selebihnya dihitung di [truncatedItems].
ReceiptScanResult? parseReceiptScanText(String raw, List<String> categories) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  // Buang pagar markdown bila model membungkus jawaban.
  s = s.replaceAll(RegExp(r'^```(\w+)?\s*'), '');
  s = s.replaceAll(RegExp(r'\s*```$'), '');
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
        break;
      case 'DATE':
        dateStr = val;
        break;
      case 'TOTAL':
        // Toleran: "115.500", "Rp 115500", "115500" -> 115500.
        final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
        total = digits.isEmpty ? null : int.tryParse(digits);
        break;
      case 'CATEGORY':
        categoryRaw = val;
        break;
    }
  }

  // total: integer murni > 0.
  if (total == null || total <= 0) return null;

  // date: format + tanggal kalender valid (cek round-trip).
  if (dateStr == null) return null;
  final ds = dateStr.trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(ds)) return null;
  final dt = DateTime.tryParse(ds);
  if (dt == null) return null;
  final back = '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
  if (back != ds) return null;

  // category: harus ada di daftar app (tak sensitif huruf).
  if (categoryRaw == null) return null;
  final ct = categoryRaw.trim().toLowerCase();
  if (ct.isEmpty) return null;
  String? canonical;
  for (final c in categories) {
    if (c.trim().toLowerCase() == ct) {
      canonical = c.trim();
      break;
    }
  }
  if (canonical == null || canonical.isEmpty) return null;

  // items: toleran, baris rusak -> dilewati.
  final scanItems = <ReceiptScanItem>[];
  var truncated = 0;
  for (; i < lines.length; i++) {
    final l = lines[i];
    // Model kadang menulis penanda singkatan sendiri -> abaikan.
    if (l.startsWith('...')) continue;
    final parts = l.split('|');
    if (parts.length < 3) continue;
    final priceDigits =
        parts.last.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final price = priceDigits.isEmpty ? null : int.tryParse(priceDigits);
    if (price == null || price < 0) continue;
    final qtyDigits = parts[parts.length - 2]
        .trim()
        .replaceAll(RegExp(r'[^0-9]'), '');
    var qty = int.tryParse(qtyDigits) ?? 1;
    if (qty <= 0 || qty > 10000) qty = 1;
    // Nama = semua segmen sebelum qty (nama boleh mengandung '|').
    var name = parts.sublist(0, parts.length - 2).join('|').trim();
    if (name.isEmpty) continue;
    if (name.length > 120) name = name.substring(0, 120);
    if (scanItems.length >= scanItemCap) {
      truncated++;
      continue;
    }
    scanItems.add(ReceiptScanItem(name: name, qty: qty, price: price));
  }

  if (merchant != null) {
    final mt = merchant.trim();
    merchant = mt.isEmpty ? null : (mt.length <= 120 ? mt : mt.substring(0, 120));
  }

  return ReceiptScanResult(
    merchant: merchant,
    date: ds,
    total: total,
    category: canonical,
    items: scanItems,
    truncatedItems: truncated,
  );
}

/// JSON mentah model -> [ReceiptScanResult] atau null bila tak valid.
/// Dipertahankan sebagai fallback bila model membalas format JSON lama.
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
    return null;
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
