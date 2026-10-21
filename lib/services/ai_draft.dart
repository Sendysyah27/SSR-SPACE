// Draft AI parser struk: JSON LLM -> struktur aman (fail-open).
//
// File SENGAJA tanpa import supaya bisa diverifikasi via `dart` murni.
// Aturan: parsial tetap lanjut (field hilang = null, bukan gagal);
// sampah total (bukan Map / semua kosong) = null → fallback manual.
import 'dart:convert';

import 'receipt_parse.dart';

class AiDraftItem {
  final String name;
  final int qty;
  final double price;
  const AiDraftItem({
    required this.name,
    this.qty = 1,
    required this.price,
  });
}

class AiDraft {
  final String? merchant;
  final String? date;

  /// Jam struk 'HH:mm' (batch 286: parser lokal menangkap jam; draft
  /// AI dari server tidak punya jam -> null).
  final String? time;
  final List<AiDraftItem> items;
  final double? subtotal;
  final double? tax;

  /// Diskon/voucher (nominal positif, batch 286).
  final double? discount;
  final double? total;
  final String? payment;
  const AiDraft({
    this.merchant,
    this.date,
    this.time,
    this.items = const [],
    this.subtotal,
    this.tax,
    this.discount,
    this.total,
    this.payment,
  });

  /// Dari hasil parser lokal ([ReceiptData]) — dipakai alur OCR
  /// on-device supaya review-nya sama dengan draft AI (batch 286).
  factory AiDraft.fromReceiptData(ReceiptData d) {
    String? dateStr;
    final dd = d.date;
    if (dd != null) {
      dateStr = '${dd.year.toString().padLeft(4, '0')}-'
          '${dd.month.toString().padLeft(2, '0')}-'
          '${dd.day.toString().padLeft(2, '0')}';
    }
    var timeStr = d.time;
    if (timeStr == null && dd != null && (dd.hour != 0 || dd.minute != 0)) {
      timeStr = '${dd.hour.toString().padLeft(2, '0')}:'
          '${dd.minute.toString().padLeft(2, '0')}';
    }
    double? subtotal;
    if (d.lineItems.isNotEmpty) {
      subtotal = d.lineItems.fold<double>(0.0, (s, e) => s + e.price);
    }
    return AiDraft(
      merchant: d.merchant,
      date: dateStr,
      time: timeStr,
      items: [
        for (final it in d.lineItems)
          AiDraftItem(name: it.name, qty: it.qty, price: it.price),
      ],
      subtotal: subtotal,
      tax: d.tax,
      discount: d.voucher,
      total: d.amount,
      payment: d.payType,
    );
  }

  /// Ke ReceiptData untuk prefill form (jujur: confident ikut total).
  /// Tanggal + jam digabung; pajak/diskon/jenis bayar ikut terbawa.
  ReceiptData toReceiptData() {
    DateTime? day;
    final ds = date;
    if (ds != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(ds)) {
      day = DateTime.tryParse(ds);
    }
    final ts = time;
    if (day != null && ts != null) {
      final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(ts);
      if (m != null) {
        final h = int.tryParse(m.group(1)!);
        final mi = int.tryParse(m.group(2)!);
        if (h != null && mi != null && h <= 23 && mi <= 59) {
          day = DateTime(day.year, day.month, day.day, h, mi);
        }
      }
    }
    return ReceiptData(
      amount: total,
      date: day,
      merchant: merchant,
      items: [
        for (final it in items)
          it.qty > 1
              ? '${it.name} x${it.qty} ${it.price.toInt()}'
              : '${it.name} ${it.price.toInt()}',
      ],
      lineItems: [
        for (final it in items)
          ReceiptItem(name: it.name, qty: it.qty, price: it.price),
      ],
      voucher: discount,
      tax: tax,
      time: time,
      payType: payment,
      confident: total != null && total! > 0,
    );
  }
}

String? _str(dynamic v, [int cap = 120]) {
  if (v is! String) return null;
  final t = v.trim();
  if (t.isEmpty) return null;
  return t.length <= cap ? t : t.substring(0, cap);
}

double? _num(dynamic v) {
  if (v is num) return v < 0 ? null : v.toDouble();
  if (v is String) {
    final n = double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), ''));
    if (n == null || n < 0) return null;
    return n;
  }
  return null;
}

int _qty(dynamic v) {
  if (v is num && v.round() == v && v >= 1 && v <= 99) return v.toInt();
  return 1;
}

/// Respons mentah LLM -> [AiDraft] atau null (tak bisa dipakai).
AiDraft? parseAiDraft(String raw) {
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
  var date = _str(m['date'], 10);
  if (date != null && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    date = null;
  }
  final items = <AiDraftItem>[];
  final rawItems = m['items'];
  if (rawItems is List) {
    for (final e in rawItems.take(30)) {
      if (e is! Map) continue;
      final im = Map<String, dynamic>.from(e);
      final name = _str(im['name'], 80);
      if (name == null) continue;
      final pv = im['price'];
      final negative = (pv is num && pv < 0) ||
          (pv is String && pv.trim().startsWith('-'));
      if (negative) continue;
      final price = _num(pv) ?? 0;
      items.add(AiDraftItem(name: name, qty: _qty(im['qty']), price: price));
    }
  }
  final draft = AiDraft(
    merchant: _str(m['merchant']),
    date: date,
    items: items,
    subtotal: _num(m['subtotal']),
    tax: _num(m['tax']),
    total: _num(m['total']),
    payment: _str(m['payment_method'] ?? m['payment'], 40),
  );
  if (draft.merchant == null &&
      draft.items.isEmpty &&
      draft.total == null) {
    return null;
  }
  return draft;
}

/// Isi choices[0].message.content dari body JSON OpenAI-compatible
/// (Zen/OpenRouter), atau null. Murni (tanpa http) agar testable via `dart`.
String? openAiContentFromBody(dynamic body) {
  try {
    final choices = body is Map ? body['choices'] : null;
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final msg = first['message'];
    if (msg is! Map) return null;
    final content = msg['content'];
    if (content is! String || content.trim().isEmpty) return null;
    return content;
  } catch (_) {
    return null;
  }
}

/// Prompt ekstraksi struk: teks OCR mentah -> JSON terstruktur.
/// Varian multi-baris wajib gabung ke produk induk (konvensi parser lokal).
String _receiptRules() =>
    'Kamu pengurai struk belanja Indonesia. Baca SELURUH struk '
    'dari atas sampai bawah dengan teliti, jangan berhenti di total '
    'pertama. Kembalikan SATU objek JSON valid saja (tanpa markdown, '
    'tanpa penjelasan) dengan kunci persis: merchant (string|null, '
    'nama gerai lengkap), date (format YYYY-MM-DD|null), items (array '
    '{name, qty, price} dalam rupiah angka), subtotal (angka|null), '
    'tax (angka|null), total (angka|null), payment_method (string|null).\n'
    'Aturan item: tiap produk = nama LENGKAP + qty + harga. Pecahan '
    'bacaan (huruf/angka nyasar mis. "g 4", "/y", "1<") BUKAN item '
    'sendiri — gabungkan ke nama produk terdekat di atas/bawahnya. '
    'Baris varian atau pilihan tanpa harga sendiri (mis. "Normal Ice", '
    '"Less Sugar", "Pilihan Nugget") BUKAN item — gabungkan ke nama '
    'produk induknya; judul pilihan saja tanpa produk = abaikan. '
    'qty = angka sebelum x/X atau sesudah nama; harga = angka paling '
    'kanan pada barisnya. Abaikan NPWP, alamat, kasir, jam, nomor '
    'struk, dan ucapan terima kasih. total = angka pada baris '
    'TOTAL/GRAND (bukan subtotal, bukan tunai/kembali). Bila ragu, '
    'null (jangan karang).';

String aiReceiptPrompt(String ocrText) {
  final capped = ocrText.length <= 4000 ? ocrText : ocrText.substring(0, 4000);
  return '${_receiptRules()}\nTEKS:\n$capped';
}

/// Prompt untuk model vision: aturan sama, sumbernya GAMBAR struk
/// (JPG/PNG) yang dilampirkan — tanpa teks OCR.
String aiVisionPrompt() =>
    '${_receiptRules()}\nGambar struk terlampir. Uraikan langsung dari gambar.';
