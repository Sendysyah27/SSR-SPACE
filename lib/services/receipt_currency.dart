import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/receipt_parse.dart';

// CurrencyResolver struk asing (batch 284 tahap B, pola
// AiReceiptCurrencyResolver Ollo): struk ber-mata-uang asing (JPY/KRW/
// USD/SGD/MYR/THB/EUR) terdeteksi dari teksnya, total dikonversi ke IDR
// memakai kurs open.er-api.com (tanpa API key — pola yang sama dipakai
// Ollo), cache prefs TTL 24 jam.
//
// Fail-open penuh: kurs tak terbaca (offline / API berubah) -> TIDAK ada
// konversi; UI menampilkan nominal asli + label mata uang agar user
// menyesuaikan manual di form (review-first). Tidak pernah throw.

/// Mata uang asing yang dikenali resolver ini.
const supportedReceiptCurrencies = {
  'JPY',
  'KRW',
  'USD',
  'SGD',
  'MYR',
  'THB',
  'EUR',
};

/// Simbol tampil per kode mata uang.
const receiptCurrencySymbols = {
  'JPY': '¥',
  'KRW': '₩',
  'USD': '\$',
  'SGD': 'S\$',
  'MYR': 'RM',
  'THB': '฿',
  'EUR': '€',
};

/// MURNI: deteksi kode mata uang asing dari teks struk / balasan model.
/// Urutan penting: simbol khas & kode eksplisit dulu, '$' polos terakhir
/// (paling ambigu -> USD). 'Rp' TIDAK pernah cocok (rupiah = tanpa
/// konversi). Null = tidak terdeteksi (anggap IDR / tak relevan).
String? detectReceiptCurrency(String text) {
  if (text.trim().isEmpty) return null;
  // Kode eksplisit 3 huruf (huruf besar, batas kata).
  for (final code in supportedReceiptCurrencies) {
    if (RegExp('\\b$code\\b').hasMatch(text)) return code;
  }
  if (text.contains('฿') || text.contains('บาท')) return 'THB';
  if (text.contains('₩') || text.contains('원')) return 'KRW';
  if (text.contains('円') || text.contains('¥')) return 'JPY';
  if (text.contains('€')) return 'EUR';
  // RM ringgit: 'RM' di batas kata, boleh diikuti angka langsung
  // (RM45.90). 'Rp' tidak cocok — pola ini menuntut M setelah R.
  if (RegExp(r'\bRM(\s?\d|\s)').hasMatch(text)) return 'MYR';
  // S$ Singapura: wajib batas kata di depan S — 'US$' TIDAK boleh ikut
  // (jebakan substring: 'US$' mengandung 'S$').
  if (RegExp(r'\bS\$').hasMatch(text)) return 'SGD';
  if (text.contains('\$')) return 'USD';
  return null;
}

/// MURNI: ekstrak kurs IDR dari body JSON open.er-api.com
/// ({"result":"success","rates":{"IDR": 105.25, ...}} = IDR per 1 unit).
double? parseErApiRate(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final rates = decoded['rates'];
    if (rates is! Map) return null;
    final v = rates['IDR'];
    if (v is num && v > 0) return v.toDouble();
    return null;
  } catch (_) {
    return null;
  }
}

/// MURNI: konversi nominal asing -> IDR dengan [rate] (IDR per 1 unit).
double convertToIdr(double amount, double rate) => amount * rate;

/// Format nominal asing untuk tampilan: simbol + grup ribuan titik;
/// USD/SGD/MYR/THB/EUR 2 desimal, JPY/KRW tanpa desimal.
String formatForeignAmount(double amount, String code) {
  final sym = receiptCurrencySymbols[code] ?? code;
  final dec = (code == 'JPY' || code == 'KRW') ? 0 : 2;
  final fixed = amount.toStringAsFixed(dec);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  final frac = dec > 0 && parts.length > 1 ? ',${parts[1]}' : '';
  return '$sym $buf$frac';
}

const _fxTtl = Duration(hours: 24);

/// Kurs IDR untuk [code]: cache prefs (TTL 24 jam) -> open.er-api.com.
/// Null = tak tersedia (fail-open; pemanggil jangan mengonversi).
Future<double?> fetchIdrRate(String code, {DateTime? now}) async {
  final c = code.toUpperCase();
  if (!supportedReceiptCurrencies.contains(c)) return null;
  final t = now ?? DateTime.now();
  final rateKey = 'fx_rate_$c';
  final atKey = 'fx_rate_at_$c';
  try {
    final p = await SharedPreferences.getInstance();
    final cached = p.getDouble(rateKey);
    final atMs = p.getInt(atKey);
    if (cached != null && cached > 0 && atMs != null) {
      final age = t.difference(DateTime.fromMillisecondsSinceEpoch(atMs));
      if (age < _fxTtl) return cached;
    }
  } catch (_) {}
  try {
    final client = HttpClient();
    try {
      final req = await client
          .getUrl(Uri.parse('https://open.er-api.com/v6/latest/$c'))
          .timeout(const Duration(seconds: 10));
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final rate = parseErApiRate(body);
      if (rate == null) return null;
      try {
        final p = await SharedPreferences.getInstance();
        await p.setDouble(rateKey, rate);
        await p.setInt(atKey, t.millisecondsSinceEpoch);
      } catch (_) {}
      return rate;
    } finally {
      client.close();
    }
  } catch (_) {
    return null;
  }
}

/// Terapkan konversi ke [data] bila struk ber-mata-uang asing
/// (fxCurrency terisi): isi fxRate + ganti amount & harga item menjadi
/// IDR (dibulatkan). Kurs gagal -> data kembali apa adanya (fxRate null)
/// agar UI menampilkan nominal asli + peringatan. IDR/tak terdeteksi ->
/// data tak berubah.
Future<ReceiptData> applyFxConversion(ReceiptData data) async {
  final code = data.fxCurrency;
  if (code == null || code == 'IDR') return data;
  final orig = data.fxOriginal ?? data.amount;
  if (orig == null || orig <= 0) return data;
  final rate = await fetchIdrRate(code);
  if (rate == null || rate <= 0) return data;
  final convertedTotal = convertToIdr(orig, rate).roundToDouble();
  return data.copyWith(
    amount: convertedTotal,
    fxRate: rate,
    lineItems: [
      for (final li in data.lineItems)
        ReceiptItem(
          name: li.name,
          qty: li.qty,
          price: convertToIdr(li.price, rate).roundToDouble(),
          suspicious: convertToIdr(li.price, rate) > convertedTotal,
        ),
    ],
  );
}
