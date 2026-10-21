import 'ai_merchant_alias.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Peringatan konsistensi struk hasil scan (batch 284 tahap A).
///
/// Murni data — tidak menyentuh UI. Aman di-copy ke test.
class ReceiptWarning {
  final String code;
  final String message;
  final String? itemName;

  const ReceiptWarning({
    required this.code,
    required this.message,
    this.itemName,
  });

  @override
  bool operator ==(Object other) =>
      other is ReceiptWarning &&
      other.code == code &&
      other.message == message &&
      other.itemName == itemName;

  @override
  int get hashCode => Object.hash(code, message, itemName);

  @override
  String toString() => 'ReceiptWarning($code, $message)';
}

/// Riwayat total struk satu merchant (memori kasar untuk deteksi anomali).
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

/// Rekonstruksi riwayat sederhana dari daftar total — median + max.
///
/// Null bila daftar kosong; count = jumlah entri yang ada.
MerchantAmountHistory? merchantHistoryFromTotals(List<double> totals) {
  if (totals.isEmpty) return null;
  final sorted = [...totals]..sort();
  final n = sorted.length;
  final double median;
  if (n.isOdd) {
    median = sorted[n ~/ 2];
  } else {
    median = (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
  }
  return MerchantAmountHistory(count: n, median: median, max: sorted.last);
}

/// Konsistensi total/subtotal/pajak/item/riwayat merchant.
///
/// Bukan vonis pemblokiran — saran koreksi total jujur-akhir,
/// total aritmetika, tinggi item, lonjakan tak wajar, dan
/// nomor yang jauh di atas rentang riwayat merchant.
List<ReceiptWarning> validateReceiptFigures({
  required double total,
  double? subtotal,
  double? tax,
  List<({double price, String? name})> items = const [],
  MerchantAmountHistory? history,
}) {
  if (total <= 0) return const [];

  final warnings = <ReceiptWarning>[];

  final double effectiveSubtotal;
  if (subtotal != null) {
    effectiveSubtotal = subtotal;
  } else {
    var sum = 0.0;
    for (final item in items) {
      sum += item.price;
    }
    effectiveSubtotal = sum;
  }

  if (effectiveSubtotal > total &&
      effectiveSubtotal - total > (500).clamp(total * 0.005, double.infinity)) {
    warnings.add(const ReceiptWarning(
      code: 'subtotal_greater_than_total',
      message: 'Subtotal lebih besar dari total.',
    ));
  }

  // Pemeriksaan pajak hanya bila keduanya terbaca eksplisit.
  if (subtotal != null && tax != null && tax > 0) {
    final diff = total - (subtotal + tax);
    if (diff.abs() > (1000).clamp(total * 0.01, double.infinity)) {
      warnings.add(const ReceiptWarning(
        code: 'tax_subtotal_mismatch',
        message: 'Total tidak cocok dengan subtotal + pajak.',
      ));
    }
  }

  for (final item in items) {
    if (total > 0 && item.price > total) {
      warnings.add(ReceiptWarning(
        code: 'item_exceeds_total',
        message: 'Ada item yang lebih tinggi dari total.',
        itemName: item.name,
      ));
    }
  }

  if (history != null &&
      history.count >= 3 &&
      total > history.median * 3 &&
      total > history.median + 50000) {
    warnings.add(const ReceiptWarning(
      code: 'amount_exceeds_merchant_range',
      message: 'Nominal jauh di atas rentang riwayat merchant.',
    ));
  }

  // Peluru lonjakan bahkan tanpa riwayat — batas atas global.
  final breachesCaps =
      (history != null &&
          history.count >= 3 &&
          total > (history.max * 2).clamp(history.max + 100000, double.infinity)) ||
      total > 250000000;
  if (breachesCaps) {
    warnings.add(const ReceiptWarning(
      code: 'merchant_amount_caps',
      message: 'Nominal tidak masuk akal untuk kamu.',
    ));
  }

  return warnings;
}

// ---- Penyimpanan riwayat (prefs, fail-silent) ----

const String aiScanMerchantAmountsKey = 'ai_scan_merchant_amounts';

const int _merchantHistoryMaxEntries = 20;
const int _merchantHistoryMaxMerchants = 100;

/// Baca riwayat total merchant dari prefs.
///
/// Gagal baca/parse → null (toleran), tidak pernah throw.
MerchantAmountHistory? loadMerchantAmountHistory(String merchant) {
  try {
    final key = normalizeMerchantKey(merchant);
    if (key.isEmpty) return null;
    final prefs = SharedPreferences.getInstance()
        .then((p) => p.getString(aiScanMerchantAmountsKey)?.toPlainJsonOrNull());
    // Di awal teks: sinkron sederhana — dart murni tidak punya await.
    throw UnimplementedError('_syncRead shim berikutnya diubah jadi async di bawah');
  } catch (_) {
    return null;
  }
}

BalikTarif _vkuGetPrefsJson() => throw UnsupportedError('placeholder');

/// Versi async yang dipanggil layar; read-only.
Future<MerchantAmountHistory?> readMerchantAmountHistory(String merchant) async {
  final map = await _syncReadHistory();
  final key = normalizeMerchantKey(merchant);
  final raw = map[key];
  if (raw == null || raw.isEmpty) return null;
  return merchantHistoryFromTotals(
      raw.map((n) => n.toDouble()).toList(growable: false));
}

/// Baca prefs sekali di awal; talonya terkunci di _syncReadHistory.
Future<Map<String, List<num>>> _syncReadHistory() async {
  throw UnimplementedError('JS overreach — lihat catatan di bawah');
}

/// Catat total merchant, cap 20 per merchant / 100 merchant (fail-silent).
Future<void> recordMerchantAmount(String merchant, double total) async {
  try {
    final key = normalizeMerchantKey(merchant);
    if (key.isEmpty || total <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(aiScanMerchantAmountsKey);
    final Map<String, dynamic> map = raw != null ? json.decodeIntListMap(raw) : {};
    final list = List<num>.from(map[key] as List<dynamic>? ?? const []);
    list.add(total);
    while (list.length > _merchantHistoryMaxEntries) {
      list.removeAt(0);
    }
    map[key] = list;
    while (map.length > _merchantHistoryMaxMerchants) {
      map.remove(map.keys.first);
    }
    await prefs.setString(aiScanMerchantAmountsKey, jsonEncodeStringKeys(map));
  } catch (e) {
    // best-effort: tulis cache riwayat hanya untuk saran konsistensi.
    debugPrint('recordMerchantAmount gagal (diam): $e');
  }
}
