import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/ai_merchant_alias.dart';
import 'package:ssr_space/services/receipt_parse.dart';

// Validator konsistensi struk (batch 284 tahap A, pola ReceiptValidator
// Ollo): aturan murah lokal atas angka hasil scan (Vision maupun OCR).
// Sifatnya PERINGATAN — tidak pernah memblokir simpan; user tetap
// memutuskan di layar review (review-first).
//
// Statistik nominal per merchant disimpan lokal (prefs) dari scan yang
// sukses; riwayat itulah bahan aturan rentang/caps ala Ollo
// (amount_exceeds_merchant_range, merchant_amount_caps). Memori alias
// 281D tidak menyimpan nominal, jadi statistiknya dicatat terpisah di
// sini. Semua IO fail-silent.

/// Satu peringatan validator.
class ReceiptWarning {
  /// Kode aturan: subtotal_greater_than_total | tax_subtotal_mismatch |
  /// item_exceeds_total | amount_exceeds_merchant_range |
  /// merchant_amount_caps.
  final String code;

  /// Pesan ramah Bahasa Indonesia untuk banner sheet review.
  final String message;

  /// Nama item terkait (aturan per-item); null untuk aturan agregat.
  final String? itemName;

  const ReceiptWarning({
    required this.code,
    required this.message,
    this.itemName,
  });
}

/// Ringkasan riwayat nominal satu merchant (dari scan sukses).
class MerchantAmountHistory {
  final int count;
  final double median;
  final double max;

  const MerchantAmountHistory({
    required this.count,
    required this.median,
    required this.max,
  });
}

/// MURNI: daftar total -> ringkasan riwayat (null bila tak ada nilai > 0).
MerchantAmountHistory? merchantHistoryFromTotals(List<double> totals) {
  final xs = totals.where((v) => v > 0).toList()..sort();
  if (xs.isEmpty) return null;
  final n = xs.length;
  final median = n.isOdd ? xs[n ~/ 2] : (xs[n ~/ 2 - 1] + xs[n ~/ 2]) / 2;
  return MerchantAmountHistory(count: n, median: median, max: xs.last);
}

/// MURNI: jalankan semua aturan atas angka struk.
///
/// [subtotal] = subtotal tercetak bila diketahui; null -> dipakai jumlah
/// harga item sebagai pendekatan. [tax]/[voucher] dari struk bila ada
/// (jalur OCR). [history] = riwayat merchant (aturan rentang/caps hanya
/// aktif bila riwayat cukup: count >= 3) — tanpa riwayat, caps statis
/// kewajaran tetap berlaku.
List<ReceiptWarning> validateReceiptFigures({
  required double total,
  double? subtotal,
  double? tax,
  double? voucher,
  List<({String name, double price})> items = const [],
  MerchantAmountHistory? history,
}) {
  final out = <ReceiptWarning>[];
  if (total <= 0) return out;
  // Toleransi pembulatan: mana yang lebih besar, Rp 500 atau 0,5% total.
  final tol = math.max(500.0, total * 0.005);
  final itemsSum = items.fold<double>(0, (s, e) => s + e.price);
  final effSubtotal = subtotal ?? (items.isEmpty ? null : itemsSum);
  if (effSubtotal != null && effSubtotal > total + tol) {
    out.add(const ReceiptWarning(
      code: 'subtotal_greater_than_total',
      message: 'Subtotal lebih besar dari total — cek lagi angka struknya.',
    ));
  }
  if (subtotal != null && tax != null && tax > 0) {
    final expected = subtotal + tax - (voucher ?? 0);
    if ((expected - total).abs() > tol) {
      out.add(const ReceiptWarning(
        code: 'tax_subtotal_mismatch',
        message:
            'Subtotal + pajak tidak cocok dengan total — cek lagi angka struknya.',
      ));
    }
  }
  for (final it in items) {
    if (it.price > total) {
      out.add(ReceiptWarning(
        code: 'item_exceeds_total',
        message: 'Harga item melebihi total struk — cek lagi baris ini.',
        itemName: it.name,
      ));
    }
  }
  var capsWarned = false;
  if (history != null && history.count >= 3) {
    if (total > history.median * 3 && total > history.median + 50000) {
      out.add(const ReceiptWarning(
        code: 'amount_exceeds_merchant_range',
        message:
            'Total jauh di atas kebiasaan merchant ini — cek lagi nominalnya.',
      ));
    }
    if (total > math.max(history.max * 2, history.max + 100000)) {
      out.add(const ReceiptWarning(
        code: 'merchant_amount_caps',
        message: 'Nominal sangat besar untuk merchant ini — pastikan tidak salah baca.',
      ));
      capsWarned = true;
    }
  }
  // Caps statis tanpa riwayat: nominal harian di atas ini hampir pasti
  // salah baca (digit nyangkut).
  if (!capsWarned && total > 250000000) {
    out.add(const ReceiptWarning(
      code: 'merchant_amount_caps',
      message: 'Nominal sangat besar untuk merchant ini — pastikan tidak salah baca.',
    ));
  }
  return out;
}

/// Kunci prefs statistik nominal merchant hasil scan.
const aiScanMerchantAmountsKey = 'ai_scan_merchant_amounts';

const _merchantAmountsCap = 100;
const _merchantTotalsCap = 20;

Future<Map<String, List<double>>> _loadMerchantAmounts() async {
  try {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(aiScanMerchantAmountsKey);
    if (raw == null || raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    final out = <String, List<double>>{};
    for (final e in decoded.entries) {
      final v = e.value;
      if (v is List) {
        out[e.key.toString()] = [
          for (final n in v)
            if (n is num) n.toDouble(),
        ];
      }
    }
    return out;
  } catch (_) {
    return {};
  }
}

/// Riwayat nominal merchant [merchant] dari scan sukses sebelumnya.
/// Fail-open: null bila belum ada data / gagal baca.
Future<MerchantAmountHistory?> loadMerchantAmountHistory(
    String merchant) async {
  final key = normalizeMerchantKey(merchant);
  if (key.isEmpty) return null;
  final map = await _loadMerchantAmounts();
  final list = map[key];
  if (list == null) return null;
  return merchantHistoryFromTotals(list);
}

/// Catat satu nominal scan sukses untuk [merchant] (fail-silent).
/// Maks [_merchantTotalsCap] entri terakhir per merchant dan
/// [_merchantAmountsCap] merchant (yang paling lama tak dipakai dibuang).
Future<void> recordMerchantAmount(String merchant, double total) async {
  try {
    if (total <= 0) return;
    final key = normalizeMerchantKey(merchant);
    if (key.isEmpty) return;
    final map = await _loadMerchantAmounts();
    final list = [...(map[key] ?? const <double>[]), total];
    while (list.length > _merchantTotalsCap) {
      list.removeAt(0);
    }
    // Sisip ulang agar merchant aktif pindah ke urutan terakhir (terbaru).
    map.remove(key);
    map[key] = list;
    while (map.length > _merchantAmountsCap) {
      map.remove(map.keys.first);
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(aiScanMerchantAmountsKey, jsonEncode(map));
  } catch (_) {}
}

/// Peringatan validator untuk satu hasil scan (memuat riwayat merchant
/// dulu). Dipakai kedua permukaan scan sebelum sheet review tampil.
Future<List<ReceiptWarning>> validateReceiptData(ReceiptData data) async {
  final total = data.amount ?? 0;
  if (total <= 0) return const [];
  MerchantAmountHistory? history;
  final merch = (data.merchant ?? '').trim();
  if (merch.isNotEmpty) history = await loadMerchantAmountHistory(merch);
  return validateReceiptFigures(
    total: total,
    tax: data.tax,
    voucher: data.voucher,
    items: [
      for (final li in data.lineItems) (name: li.name, price: li.price),
    ],
    history: history,
  );
}

/// Catat nominal hasil scan ke statistik merchant (fail-silent).
Future<void> recordScanAmount(ReceiptData data) async {
  final merch = (data.merchant ?? '').trim();
  final total = data.amount ?? 0;
  if (merch.isEmpty || total <= 0) return;
  await recordMerchantAmount(merch, total);
}
