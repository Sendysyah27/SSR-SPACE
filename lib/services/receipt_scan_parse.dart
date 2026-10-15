// Parser + prompt scan struk via OpenCode lokal.
//
// File SENGAJA hanya import dart:convert supaya murni dan mudah dites
// (`flutter test`). Uang = int (rupiah). Tidak ada log data di sini.

import 'dart:convert';

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

  const ReceiptScanResult({
    this.merchant,
    required this.date,
    required this.total,
    required this.category,
  });
}

/// System prompt untuk scan struk: model HARUS membalas satu objek JSON
/// saja, tanpa markdown, tanpa penjelasan. Dibuat di Dart (bukan
/// DEFAULT_SYSTEM Kotlin yang untuk chat).
String scanReceiptSystemPrompt(List<String> categories) {
  final cats = categories.map((c) => c.trim()).where((c) => c.isNotEmpty).join(', ');
  return 'Kamu pengurai struk belanja Indonesia. Baca gambar struk dengan teliti '
      'dari atas sampai bawah. Balas HANYA satu objek JSON valid dengan kunci persis: '
      '{"merchant":"nama gerai atau string kosong","date":"YYYY-MM-DD",'
      '"total":<integer>,"category":"..."}. '
      'Aturan: total = GRAND TOTAL yang dibayar (SETELAH diskon), dalam rupiah '
      'sebagai integer murni (contoh 16000; bukan "16000", bukan 16000.0). '
      'date = tanggal transaksi format YYYY-MM-DD. '
      'category = salah satu dari: $cats. '
      'Jangan pakai tool. Jangan karang angka bila ragu.';
}

/// Prompt varian teks-OCR (fallback bila model buta gambar).
String scanReceiptOcrPrompt(String ocrText, List<String> categories) {
  final capped = ocrText.length <= 4000 ? ocrText : ocrText.substring(0, 4000);
  return '${scanReceiptSystemPrompt(categories)}\nTEKS OCR STRUK:\n$capped';
}

/// JSON mentah model -> [ReceiptScanResult] atau null bila tak valid.
///
/// Validasi ketat:
/// - total HARUS int > 0 (tolak 0, negatif, double, string)
/// - date HARUS YYYY-MM-DD dan tanggal kalender valid
/// - category HARUS cocok (tak sensitif huruf-besar) dengan [categories]
/// - merchant opsional
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
  );
}
