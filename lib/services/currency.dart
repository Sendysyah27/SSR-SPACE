import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/app_settings.dart';

const _kRates = 'fx_rates_json';
const _kRatesAt = 'fx_rates_at';

/// Nilai tukar vs IDR (1 IDR = x asing). Cache prefs + refresh API.
class CurrencyService {
  CurrencyService._();

  static Map<String, double> rates = {};
  static DateTime? fetchedAt;

  static Future<void> loadCache(SharedPreferences prefs) async {
    final raw = prefs.getString(_kRates);
    if (raw == null) return;
    try {
      final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      rates = {
        for (final e in m.entries)
          if (e.value is num) e.key: (e.value as num).toDouble(),
      };
      final at = prefs.getInt(_kRatesAt);
      if (at != null) {
        fetchedAt = DateTime.fromMillisecondsSinceEpoch(at);
      }
    } catch (_) {}
  }

  /// Ambil kurs terbaru (gratis, tanpa kunci). Gagal = pakai cache.
  static Future<bool> refresh() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 12);
      final req = await client.getUrl(
        Uri.parse('https://open.er-api.com/v6/latest/IDR'),
      );
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return false;
      final body = await res.transform(utf8.decoder).join();
      final m = Map<String, dynamic>.from(jsonDecode(body) as Map);
      final r = Map<String, dynamic>.from(m['rates'] as Map);
      final next = <String, double>{};
      for (final code in kCurrencySymbols.keys) {
        final v = r[code];
        if (v is num) next[code] = v.toDouble();
      }
      if (next.isEmpty) return false;
      rates = next;
      fetchedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kRates, jsonEncode(next));
      await prefs.setInt(_kRatesAt, fetchedAt!.millisecondsSinceEpoch);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Konversi nominal IDR ke mata uang aktif.
  static double convert(num idrAmount) {
    final code = currencyCode.value;
    if (code == 'IDR') return idrAmount.toDouble();
    final r = rates[code];
    if (r == null) return idrAmount.toDouble();
    return idrAmount.toDouble() * r;
  }

  /// Kembalikan input mata uang aktif ke IDR untuk disimpan.
  static double toIdr(num displayed) {
    final code = currencyCode.value;
    if (code == 'IDR') return displayed.toDouble();
    final r = rates[code];
    if (r == null || r == 0) return displayed.toDouble();
    return displayed.toDouble() / r;
  }

  /// Format nominal IDR ke mata uang + simbol aktif. Grup ribuan IDR
  /// ikut pengaturan format angka ('id' vs 'us'); non-IDR tetap en_US.
  static String format(num idrAmount) {
    final code = currencyCode.value;
    final symbol = kCurrencySymbols[code] ?? 'Rp';
    // Standar BI: "Rp 1.250.000" (spasi setelah Rp). Non-IDR tak berubah.
    final sym = code == 'IDR' ? 'Rp ' : symbol;
    final dec = kCurrencyDecimals(code);
    final v = convert(idrAmount);
    final locale = code == 'IDR'
        ? (numberFormat.value == 'us' ? 'en_US' : 'id_ID')
        : 'en_US';
    final f = NumberFormat.currency(
      locale: locale,
      symbol: sym,
      decimalDigits: dec,
    );
    return f.format(v);
  }

  static String placeholder() {
    final symbol = kCurrencySymbols[currencyCode.value] ?? 'Rp';
    return '$symbol ••••••';
  }
}
