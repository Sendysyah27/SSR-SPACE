// Parser struk belanja dari teks OCR mentah (ML Kit on-device).
//
// File SENGAJA tanpa import apa pun supaya bisa diverifikasi via `dart`
// murni di Termux. UI hanya memanggil parseReceipt; validasi akhir tetap
// di TransactionService saat simpan.

/// Hasil urai struk. `confident` true hanya bila total eksplisit ketemu.
class ReceiptItem {
  final String name;
  final int qty;
  final double price;
  /// True bila harga item melebihi total struk (perlu diperiksa manual).
  final bool suspicious;
  const ReceiptItem(
      {required this.name,
      this.qty = 1,
      required this.price,
      this.suspicious = false});
}

class ReceiptData {
  final double? amount;
  final DateTime? date;
  final String? merchant;
  final List<String> items;
  final List<ReceiptItem> lineItems;
  final double? voucher;
  final bool confident;
  final String? address;
  final String? cashier;
  final String? phone;
  final String? receiptNo;
  final String? time;
  final String? payType;
  /// Pajak (ppn) yang terdeteksi di struk, bila ada.
  final double? tax;
  /// False bila tanggal tidak ketemu di struk (form memakai hari ini).
  final bool dateFromReceipt;
  /// True bila jumlah item (+pajak -diskon) tak cocok dengan total.
  final bool inconsistent;
  /// Teks detail struk (format struk) dari vision scan, untuk disimpan
  /// sebagai catatan transaksi. Null bila tidak ada.
  final String? detailText;
  const ReceiptData({
    this.amount,
    this.date,
    this.merchant,
    this.items = const [],
    this.lineItems = const [],
    this.voucher,
    this.confident = false,
    this.address,
    this.cashier,
    this.phone,
    this.receiptNo,
    this.time,
    this.payType,
    this.tax,
    this.dateFromReceipt = true,
    this.inconsistent = false,
    this.detailText,
  });
}

final _totalKey = RegExp(
    r'\btotal\b|tot\s|subtotal|pembayaran|\bjumlah\b|bayar|grand',
    caseSensitive: false);
/// Label subtotal (untuk rakitan total prioritas 2).
final _subtotalKey = RegExp(r'subtotal', caseSensitive: false);
final _tenderKey =
    RegExp(r'tunai|kembali', caseSensitive: false);
final _grandKey = RegExp(r'grand', caseSensitive: false);
final _countKey = RegExp(r'item|qty|pax', caseSensitive: false);
final _payKey = RegExp(
  r'gopay|ovo|dana|qris|shopeepay|linkaja|debit|non tunai|e-money|emoney',
  caseSensitive: false,
);
final _cashKey = RegExp(r'tunai|cash', caseSensitive: false);
final _changeKey = RegExp(r'kembali', caseSensitive: false);
final _codeKey = RegExp(
  r'npwp|trxid|id poinku|no order',
  caseSensitive: false,
);
/// Fragmen non-produk: server/wifi, order, alamat, member, kontak, dsb.
final _fragKey = RegExp(
  r'server|wifi|password|username|user\s?name|login|order|jalan|\bjl\b|kec\b|kab\b|kel\b|npwp|trxid|member|terima|kasih|layanan|stamp|poin|struk|transaksi|whatsapp|whats|tlp|telp|telepon|hubungi|\bhp\b|http|www|@|^pt\b|^cv\b|^ud\b|tbk',
  caseSensitive: false,
);

/// Baris kontak/telepon: awalan + cared, atau digit polos ≥8 (harga
/// pakai pemisah; digit polos panjang = HP/kode).
bool _phoneLine(String l) {
  if (RegExp(r'\+\s*\d').hasMatch(l)) return true;
  return RegExp(r'\d{8,}').hasMatch(l);
}

/// Calon fragmen nama produk: tanpa angka, berhuruf, bukan baris khusus.
bool _isFragment(String l) {
  final t = l.trim();
  if (t.length < 3 || t.length > 40) return false;
  if (RegExp(r'[A-Za-z]').allMatches(t).length < 3) return false;
  return !_isTotalLine(t) &&
      !_rejectKey.hasMatch(t) &&
      !_fragKey.hasMatch(t) &&
      !_knownMerchant.hasMatch(t);
}

/// Kepala pendek: ada angka tapi teks depannya nyaris kosong (qty).
bool _shortHead(String l) {
  final m = _numRe.firstMatch(l);
  if (m == null) return false;
  final head = l.substring(0, m.start);
  return RegExp(r'[A-Za-z]').allMatches(head).length < 3;
}
final _pureAmount = RegExp(r'^[Rp\s.:]*\(?[\d.,]+\)?\s*$');

/// Nominal struk realistis: di bawah Rp100 pasti cacah (qty/jumlah
/// item), bukan uang.
bool _okAmount(double? v) => v != null && v >= 100;

/// Baris total toleran OCR: spasi nyasar ("TOTA L") + 0/O ("T0TAL") +
/// "1 tal"/"1tal" (kata "Total" rusak).
bool _isTotalLine(String l) {
  // Merek "TotalProtect"/"Total Protect" BUKAN baris total
  // (OCR kadang memisahkan jadi "Total Protect").
  if (RegExp(r'total\s*protect', caseSensitive: false).hasMatch(l)) {
    return false;
  }
  if (_totalKey.hasMatch(l)) return true;
  // OCR rusak ("T0TAL", "TOTA L"): spasi dibuang, 0 -> o. Suffix yang
  // diizinkan sempit (belanja/bayar/jumlah) supaya merek seperti
  // "TotalProtect" tetap lolos sebagai BUKAN total.
  final n = l.toLowerCase().replaceAll(' ', '').replaceAll('0', 'o');
  if (RegExp(r'(^|[^a-z])total(belanja|bayar|jumlah)?([^a-z]|$)')
      .hasMatch(n)) {
    return true;
  }
  // "1 tal"/"1tal" = "Total" yang rusak berat.
  return RegExp(r'(^|[^a-z0-9])1\s*tal([^a-z]|$)')
      .hasMatch(l.toLowerCase());
}
final _rejectKey = RegExp(
  r'kembali|tunai|dpp|ppn|harga jual|purchase|hemat|trxid',
  caseSensitive: false,
);
final _numRe = RegExp(r'\(?[\d.,]+\)?');
final _dateRe = RegExp(r'(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})');

/// Tanggal nama-bulan: "21 Jun 2026", "05 Desember 2026".
/// Bulan singkat/panjang Indonesia + Inggris. Jam diabaikan.
final _dateNameRe =
    RegExp(r'(\d{1,2})\s+([A-Za-z]{3,9})\s*,?\s*(\d{2,4})');
const _monthNum = <String, int>{
  'jan': 1, 'januari': 1, 'january': 1,
  'feb': 2, 'februari': 2, 'february': 2,
  'mar': 3, 'maret': 3, 'march': 3,
  'apr': 4, 'april': 4,
  'mei': 5, 'may': 5,
  'jun': 6, 'juni': 6, 'june': 6,
  'jul': 7, 'juli': 7, 'july': 7,
  'agu': 8, 'agustus': 8, 'aug': 8, 'august': 8,
  'sep': 9, 'sept': 9, 'september': 9,
  'okt': 10, 'oktober': 10, 'oct': 10, 'october': 10,
  'nov': 11, 'november': 11,
  'des': 12, 'desember': 12, 'dec': 12, 'december': 12,
};

/// Baris pembulatan: nilainya TAK PERNAH boleh jadi total.
final _roundingKey = RegExp(r'pembulatan|rounding', caseSensitive: false);

/// Baris pajak.
final _taxKey = RegExp(r'\bpajak\b|\bppn\b', caseSensitive: false);

/// Baris tender/pajak/pembulatan: BUKAN item dagangan.
final _nonItemKey = RegExp(
  r'pajak|pembulatan|tunai|cash|kembali|gopay|qris|ovo|dana|debit|kartu',
  caseSensitive: false,
);

/// True bila baris ke-[i] berkaitan dengan pembulatan: labelnya sendiri,
/// atau angka murni yang menempel <=2 baris dari label pembulatan tanpa
/// angka (label telanjang yang nilainya nyasar ke baris berikut).
bool _isRoundingValue(List<String> lines, int i) {
  if (_roundingKey.hasMatch(lines[i])) return true;
  for (var k = i - 2; k <= i + 2; k++) {
    if (k < 0 || k >= lines.length || k == i) continue;
    if (_roundingKey.hasMatch(lines[k]) && !_numRe.hasMatch(lines[k])) {
      return true;
    }
  }
  return false;
}
final _merchantLine = RegExp(r'^[A-Z0-9 .,&()/-]{4,30}$');
final _knownMerchant = RegExp(
  r'indomaret|indomarco|alfamart|alfamidi',
  caseSensitive: false,
);

/// Keyword mentah -> nama merchant rapi.
String _merchantName(String hit) {
  final l = hit.toLowerCase();
  if (l.contains('indomaret') || l.contains('indomarco')) return 'INDOMARET';
  if (l.contains('alfamart')) return 'ALFAMART';
  if (l.contains('alfamidi')) return 'ALFAMIDI';
  return hit.toUpperCase();
}
final _voucherKey = RegExp(r'voucher|diskon|potongan', caseSensitive: false);

/// `172,300` / `172.300` / `507,600.00` -> rupiah. Null bila tak valid.
double? _toIdr(String raw) {
  var n = raw.trim();
  var neg = false;
  if (n.startsWith('(') && n.endsWith(')')) {
    neg = true;
    n = n.substring(1, n.length - 1);
  }
  n = n.replaceAll(' ', '');
  final hasDot = n.contains('.');
  final hasComma = n.contains(',');
  String norm;
  if (hasDot && hasComma) {
    norm = n.lastIndexOf('.') > n.lastIndexOf(',')
        ? n.replaceAll(',', '')
        : n.replaceAll('.', '').replaceAll(',', '.');
  } else if (hasComma) {
    final parts = n.split(',');
    norm = parts.length == 2 && parts[1].length <= 2
        ? '${parts[0]}.${parts[1]}'
        : n.replaceAll(',', '');
  } else if (hasDot) {
    final parts = n.split('.');
    final thou =
        parts.length > 1 && parts.skip(1).every((p) => p.length == 3);
    norm = thou ? n.replaceAll('.', '') : n;
  } else {
    norm = n;
  }
  final v = double.tryParse(norm);
  if (v == null || v <= 0) return null;
  return neg ? -v : v;
}

double? _lastAmount(String line) {
  double? best;
  for (final m in _numRe.allMatches(line)) {
    final v = _toIdr(m.group(0)!);
    if (v != null) best = v;
  }
  return best;
}

/// Total dari label telanjang: angka murni pertama di ≤3 baris berikut
/// label TOTAL/GRAND terakhir, WAJIB dikonfirmasi baris tender/bayar
/// (tunai/kembali/qris/debit/e-money) di ≤3 baris sesudah kandidat.
/// Grand dicek dulu (menang), lalu total. Tanpa konfirmasi = null.
double? _labelledTotal(List<String> lines) {
  for (final grandFirst in [true, false]) {
    var labelIdx = -1;
    for (var i = lines.length - 1; i >= 0; i--) {
      final l = lines[i];
      final hit = grandFirst
          ? _grandKey.hasMatch(l)
          : (_isTotalLine(l) && !_grandKey.hasMatch(l));
      if (!hit || _countKey.hasMatch(l) || _numRe.hasMatch(l)) continue;
      labelIdx = i;
      break;
    }
    if (labelIdx < 0) continue;
    for (var j = labelIdx + 1;
        j < lines.length && j <= labelIdx + 3;
        j++) {
      final c = lines[j];
      if (!_pureAmount.hasMatch(c) || RegExp(r'^\d+\s+\d').hasMatch(c)) {
        continue;
      }
      final v = _lastAmount(c);
      if (!_okAmount(v)) continue;
      // Nilai pembulatan tak pernah jadi total.
      if (_isRoundingValue(lines, j)) continue;
      for (var k = j + 1; k < lines.length && k <= j + 3; k++) {
        if (_cashKey.hasMatch(lines[k]) ||
            _changeKey.hasMatch(lines[k]) ||
            _payKey.hasMatch(lines[k])) {
          return v;
        }
      }
      break;
    }
  }
  return null;
}

/// Kata varian produk (topping/level/suhu): baris khusus ini BUKAN item
/// sendiri, melainkan ekor nama produk di baris sebelumnya. Daftar
/// sengaja sempit (kata produk seperti "es"/"susu"/"dingin" DIKECUALIKAN
/// supaya "ES TEH MANIS" tak tertelan).
final _variantKey = RegExp(
    r'\b(ice|hot|regular|large|medium|small|blend|milk|sugar|less|more|'
    r'normal|sweet|panas|manis|topping|extra|level|pedas)\b',
    caseSensitive: false);

/// Penanda sub-item pilihan: tak pernah gabung mundur ke induk
/// ("Pilihan Nugget" tetap baris sendiri, harga ikut maju).
final _choiceKey = RegExp(
    r'\b(pilihan|pilih|paket|upgrade|add on|tambah)\b',
    caseSensitive: false);

/// Gabung baris varian ke nama produk sebelumnya. Syarat ketat: baris
/// tanpa angka + varian + bukan pilihan + baris sebelumnya juga tanpa
/// angka, minimal 2 kata (gerai 1 kata seperti "TOKO" tak ditempeli),
/// dan bukan total/tender/konten-header (kasir/no/telp/tanggal).
List<String> _mergeVariants(List<String> lines) {
  final out = <String>[];
  for (final l in lines) {
    final prev = out.isEmpty ? null : out.last;
    final prevWords =
        prev == null ? 0 : prev.trim().split(RegExp(r'\s+')).length;
    if (prev != null &&
        !_numRe.hasMatch(l) &&
        _variantKey.hasMatch(l) &&
        !_choiceKey.hasMatch(l) &&
        !_numRe.hasMatch(prev) &&
        prevWords >= 2 &&
        !_isTotalLine(prev) &&
        !_cashKey.hasMatch(prev) &&
        !_changeKey.hasMatch(prev) &&
        !_payKey.hasMatch(prev) &&
        !_voucherKey.hasMatch(prev) &&
        !_cashierKey.hasMatch(prev) &&
        _noId(prev) == null &&
        !_telpKey.hasMatch(prev) &&
        !_dateRe.hasMatch(prev)) {
      out[out.length - 1] = '$prev $l';
    } else {
      out.add(l);
    }
  }
  return out;
}

/// Buang pasangan void: baris bernominal + baris berikut yang nilainya
/// negatif identik ("304.000" lalu "-304.000"/"(304.000)"). Keduanya
/// dibuang (batal transaksi). Diskon Solo negatif tanpa pasangan tetap.
List<String> _dropVoids(List<String> lines) {
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (i + 1 < lines.length) {
      final v = _lastAmount(l);
      if (v != null && v > 0 && _isVoidOf(lines[i + 1], v)) {
        i++;
        continue;
      }
    }
    out.add(l);
  }
  return out;
}

/// True bila [line] adalah lawan-void [v]: "-V" atau "(V)".
bool _isVoidOf(String line, double v) {
  var t = line.trim();
  var neg = false;
  if (t.startsWith('-')) {
    neg = true;
    t = t.substring(1).trim();
  } else if (t.startsWith('(') && t.endsWith(')')) {
    neg = true;
    t = t.substring(1, t.length - 1);
  } else {
    return false;
  }
  final n = _toIdr(t);
  return neg && n != null && (n - v).abs() < 0.005;
}

/// Selisih jumlah item vs total di luar toleransi (Rp1000 dan 5%):
/// sinyal parsing ngaco → pemicu AI fallback. Kosong/valid = false.
bool itemsMismatch(List<double> prices, double? total) {
  if (total == null || total <= 0 || prices.isEmpty) return false;
  var sum = 0.0;
  for (final p in prices) {
    sum += p;
  }
  final diff = (sum - total).abs();
  return diff > 1000 && diff > total * 0.05;
}

/// Urut prioritas: baris kunci TOTAL dulu, abaikan baris pengecoh.
ReceiptData parseReceipt(String raw) {
  final lines = _dropVoids(_mergeVariants(raw
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList()));
  if (lines.isEmpty) return const ReceiptData();

  // Batas item vs footer: baris total pertama yang berangka, atau
  // "TOTAL :" yang angka murninya di baris berikut (batas setelah angka).
  // "TOTAL" telanjang / "TOTAL ITEM" cacah bukan batas (banyak struk
  // menaruhnya di atas sebagai kepala seksi). Item hanya dari zona
  // pra-total; footer (PT, alamat, NPWP, terima kasih) di bawahnya tak
  // boleh jadi item. Tanpa total = fallback perilaku lama.
  var totalIdx = lines.length;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (!_isTotalLine(l) || _countKey.hasMatch(l)) continue;
    if (_numRe.hasMatch(l)) {
      totalIdx = i;
      break;
    }
    if (i + 1 < lines.length &&
        _numRe.allMatches(l).isEmpty &&
        _pureAmount.hasMatch(lines[i + 1].trim())) {
      totalIdx = i + 2;
      break;
    }
  }

  double? amount;
  double? grand;
  var seenTotal = false;
  var seenGrandMangled = false;
  // Prioritas (2): komponen rakitan total.
  double? subtotalVal;
  var subtotalIncludesTax = false;
  double? roundingVal;
  var sawExplicitTotal = false;
  // Total terakhir SEBELUM tender pertama (diutamakan bila ada tender).
  double? preTenderTotal;
  var tenderSeen = false;
  // Suara angka nyasar (baris murni angka, bukan pengecoh, bukan "1 25000").
  // Voucher tak ikut suara (nominal promo bukan belanja).
  final votes = <double, int>{};
  for (var vi = 0; vi < lines.length; vi++) {
    final l = lines[vi];
    if (_rejectKey.hasMatch(l) ||
        _voucherKey.hasMatch(l) ||
        !_pureAmount.hasMatch(l)) {
      continue;
    }
    if (RegExp(r'^\d+\s+\d').hasMatch(l)) continue;
    // Nilai pembulatan tak pernah jadi total.
    if (_isRoundingValue(lines, vi)) continue;
    final v = _lastAmount(l);
    if (v != null) votes[v] = (votes[v] ?? 0) + 1;
  }
  final singleDetached = votes.length == 1 && votes.values.first == 1;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    final isTotal = _isTotalLine(l);
    if (isTotal) seenTotal = true;
    // Penanda tender di awal body (cabang bawah ada yang `continue`).
    final isTenderLine = _cashKey.hasMatch(l) ||
        _changeKey.hasMatch(l) ||
        _payKey.hasMatch(l);
    // "TOTAL ITEM: 2" = cacah barang, bukan uang.
    if (isTotal && _countKey.hasMatch(l)) continue;
    // Lacak subtotal untuk rakitan prioritas (2), walau barisnya kena
    // _rejectKey (mis. "Subtotal (Termasuk PPN)").
    if (isTotal && _subtotalKey.hasMatch(l)) {
      final sv = _lastAmount(l);
      if (_okAmount(sv)) {
        subtotalVal = sv;
        if (l.toLowerCase().contains('termasuk')) subtotalIncludesTax = true;
      }
    }
    if (!isTotal || _rejectKey.hasMatch(l)) {
      // Baris gabung ("TOTAL 41.250 TUNAI 50.000"): ambil angka sebelum
      // ekor tunai/kembali, jangan buang barisnya.
      if (isTotal && _tenderKey.hasMatch(l)) {
        final cut = _tenderKey.firstMatch(l)!.start;
        final v = _lastAmount(l.substring(0, cut));
        if (_okAmount(v)) {
          if (amount == null || v! > amount) amount = v;
          preTenderTotal = v;
        }
        tenderSeen = true;
      } else if (isTotal && _grandKey.hasMatch(l)) {
        seenGrandMangled = true;
      }
      if (isTenderLine) tenderSeen = true;
      continue;
    }
    var v = _lastAmount(l);
    // Total & angka di baris terpisah ("TOTAL :" / "41.250"): intip baris
    // berikut hanya bila cuma satu angka nyasar di struk (kalau banyak,
    // intip bisa comot TUNAI/KEMBALI — biar modus yang putuskan).
    if (v == null &&
        singleDetached &&
        _numRe.allMatches(l).isEmpty &&
        i + 1 < lines.length) {
      final nx = lines[i + 1];
      if (!_rejectKey.hasMatch(nx) && _pureAmount.hasMatch(nx)) {
        v = _lastAmount(nx);
      }
    }
    if (!_okAmount(v)) {
      if (isTotal && _grandKey.hasMatch(l)) seenGrandMangled = true;
    } else {
      if (isTotal && _grandKey.hasMatch(l)) {
        if (grand == null || v! > grand) grand = v;
      } else if (amount == null || v! > amount) {
        amount = v;
      }
      if (isTotal && !_subtotalKey.hasMatch(l)) {
        sawExplicitTotal = true;
      }
      // Nilai pembulatan mandiri ("Pembulatan: -100") untuk rakitan.
      if (_roundingKey.hasMatch(l) && !_isTotalLine(l)) {
        final rv = _lastAmount(l);
        if (rv != null) {
          final neg = RegExp(r'-\s*\(?[\d.,]+').hasMatch(l);
          roundingVal = neg ? -rv : rv;
        }
      }
      if (!tenderSeen && _okAmount(v)) preTenderTotal = v;
    }
    if (isTenderLine) tenderSeen = true;
  }
  // Tender ada → total terakhir sebelum tender (bukan max sedunia).
  if (tenderSeen && preTenderTotal != null) amount = preTenderTotal;
  // Grand total menang atas subtotal/total (nominal akhir yang dibayar).
  if (grand != null) amount = grand;
  // PRIORITAS UTAMA: label TOTAL/GRAND telanjang + angka murni di ≤3
  // baris berikut + Tender sesudahnya. Label ada tapi tak terkonfirmasi
  // = tolak (bukan comot) → fallback lama yang putuskan.
  amount ??= _labelledTotal(lines);
  // Struk QRIS: jumlah dibayar = total.
  if (amount == null) {
    for (final l in lines) {
      if (!RegExp(r'purchase\s*:', caseSensitive: false).hasMatch(l)) {
        continue;
      }
      final v = _lastAmount(l);
      if (_okAmount(v)) {
        amount = v;
        break;
      }
    }
  }
  // Grand cacat ("Grand Total: .0"): uang yang benar dibayar = kandidat
  // terkuat. E-money/QRIS selalu pas; tunai hanya bila tanpa kembalian
  // (tunai lebih = ada baris KEMBALI, bukan belanja).
  if (seenGrandMangled) {
    final hasChange = lines.any((l) => _changeKey.hasMatch(l));
    for (final l in lines) {
      if (_isTotalLine(l) || _changeKey.hasMatch(l)) continue;
      final emoney = _payKey.hasMatch(l);
      final cash = !emoney && _cashKey.hasMatch(l) && !hasChange;
      if (!emoney && !cash) continue;
      final v = _lastAmount(l);
      if (_okAmount(v) && v! > (amount ?? 0)) amount = v;
    }
  }
  // Relasi tunai - kembali == total (label tanpa angka + angka nyasar).
  // Satu triple {a<b<c} terbaca dua arah, jadi butuh label tunai/kembali
  // + aturan tengah: kembalian selalu terkecil, tunai terbesar.
  if (amount == null && seenTotal) {
    var bareCash = false;
    var bareChange = false;
    for (final l in lines) {
      if (_numRe.hasMatch(l)) continue;
      if (_cashKey.hasMatch(l)) bareCash = true;
      if (_changeKey.hasMatch(l)) bareChange = true;
    }
    if (bareCash || bareChange) {
      final pool = <double>[
        for (final v in votes.keys)
          if (_okAmount(v)) v,
      ];
      final triples = <String, List<double>>{};
      for (final x in pool) {
        for (final y in pool) {
          if (x <= y) continue;
          final z = x - y;
          for (final c in pool) {
            if (c == x || c == y || (c - z).abs() >= 0.005) continue;
            final t = [x, y, c]..sort();
            triples[t.join('|')] = t;
          }
        }
      }
      if (triples.length == 1) amount = triples.values.first[1];
    }
  }
  // Jumlah harga barang == total nyasar (kode/NPWP/TRXID bukan barang).
  if (amount == null && seenTotal) {
    final items = <double>[];
    for (final l in lines) {
      if (_isTotalLine(l) ||
          _rejectKey.hasMatch(l) ||
          _voucherKey.hasMatch(l) ||
          _codeKey.hasMatch(l) ||
          _dateRe.hasMatch(l) ||
          !_numRe.hasMatch(l) ||
          _pureAmount.hasMatch(l)) {
        continue;
      }
      final v = _lastAmount(l);
      if (_okAmount(v)) items.add(v!);
    }
    if (items.length >= 2 && items.length <= 12) {
      final targets = <double>{
        for (final v in votes.keys)
          if (_okAmount(v)) v,
      };
      final matched = <double>{};
      final combos = 1 << items.length;
      for (var mask = 0; mask < combos; mask++) {
        var count = 0;
        var sum = 0.0;
        for (var b = 0; b < items.length; b++) {
          if (mask & (1 << b) != 0) {
            count++;
            sum += items[b];
          }
        }
        if (count < 2) continue;
        for (final t in targets) {
          if ((t - sum).abs() < 0.005) matched.add(t);
        }
      }
      if (matched.length == 1) amount = matched.first;
    }
  }
  // Total kecopot (ada baris total, angka nyasar): modus suara ≥2,
  // pemenang tunggal. Seri = tolak (lebih baik null daripada salah).
  if (amount == null && seenTotal) {
    double? best;
    var bestN = 0;
    var tied = false;
    votes.forEach((v, n) {
      if (n > bestN) {
        best = v;
        bestN = n;
        tied = false;
      } else if (n == bestN) {
        tied = true;
      }
    });
    if (best != null && bestN >= 2 && !tied && _okAmount(best)) {
      amount = best;
    }
  }
  // Fallback `Rp xxx` tunggal bila tak ada baris TOTAL (tetap tak confident
  // bila kandidat lebih dari satu).
  if (amount == null) {
    final rpLines = [
      for (final l in lines)
        if (RegExp(r'rp\b', caseSensitive: false).hasMatch(l) &&
            !_rejectKey.hasMatch(l))
          l,
    ];
    if (rpLines.length == 1) {
      final v = _lastAmount(rpLines.first);
      if (_okAmount(v)) amount = v;
    }
  }

  DateTime? date;
  final nowYear = DateTime.now().year;
  for (final l in lines) {
    for (final m in _dateRe.allMatches(l)) {
      final d = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      var y = int.tryParse(m.group(3)!);
      if (d == null || mo == null || y == null) continue;
      if (y < 100) y += 2000;
      // Struk tak bertanggal masa depan: potongan OCR ("06/02/29")
      // bukan tanggal belanja.
      if (d < 1 || d > 31 || mo < 1 || mo > 12 || y < 2000 || y > nowYear + 1) {
        continue;
      }
      date = DateTime(y, mo, d);
    }
  }
  // Tanggal nama-bulan ("21 Jun 2026"): fallback bila tak ada tanggal
  // angka. Jam diabaikan; tanggal kalender harus valid.
  if (date == null) {
    for (final l in lines) {
      for (final m in _dateNameRe.allMatches(l)) {
        final d = int.tryParse(m.group(1)!);
        final mo = _monthNum[m.group(2)!.toLowerCase()];
        var y = int.tryParse(m.group(3)!);
        if (d == null || mo == null || y == null) continue;
        if (y < 100) y += 2000;
        if (d < 1 || d > 31 || y < 2000 || y > nowYear + 1) continue;
        final dt = DateTime(y, mo, d);
        if (dt.day != d || dt.month != mo) continue;
        date = dt;
      }
    }
  }

  String? merchant;
  for (final l in lines) {
    if (_knownMerchant.hasMatch(l)) {
      merchant = _merchantName(_knownMerchant.firstMatch(l)!.group(0)!);
      break;
    }
  }
  merchant ??= () {
    for (final l in lines) {
      if (_merchantLine.hasMatch(l) &&
          _numRe.allMatches(l).length <= 1 &&
          RegExp(r'[A-Za-z]').allMatches(l).length >= 3) {
        return l;
      }
    }
    return null;
  }();

  final items = <String>[];
  final lineItems = <ReceiptItem>[];
  double? voucher;
  for (var i = 0; i < totalIdx; i++) {
    var l = lines[i];
    // Voucher/diskon: catat nominalnya, jangan jadi item.
    if (_voucherKey.hasMatch(l) && !_totalKey.hasMatch(l)) {
      final v = _lastAmount(l);
      if (v != null) voucher = (voucher ?? 0) + v.abs();
      continue;
    }
    // Gabung baris terfragmentasi ("Kopi Kenangan Mantan" / "1 25000").
    // Intip dibatasi zona pra-total (jangan comot baris TOTAL).
    if (i + 1 < totalIdx &&
        !_numRe.hasMatch(l) &&
        _isFragment(l) &&
        _shortHead(lines[i + 1])) {
      l = '$l ${lines[i + 1]}';
      i++;
    }
    if (_isTotalLine(l) ||
        _rejectKey.hasMatch(l) ||
        _nonItemKey.hasMatch(l) ||
        _fragKey.hasMatch(l) ||
        _codeKey.hasMatch(l) ||
        _isNoLine(l) ||
        _phoneLine(l) ||
        _dateRe.hasMatch(l) ||
        _dateNameRe.hasMatch(l)) {
      continue;
    }
    final nums = _numRe.allMatches(l).toList();
    if (nums.isEmpty) continue;
    var name = l.substring(0, nums.first.start).trim();
    // Baris "2 x Rp35.909 Rp71.818*": nama produk ada di baris
    // sebelumnya bila nama di baris ini kosong.
    if (RegExp(r'[A-Za-z]').allMatches(name).length < 3 &&
        RegExp(r'^\d+\s*x\b', caseSensitive: false).hasMatch(l) &&
        i > 0) {
      final prev = lines[i - 1];
      if (!_isTotalLine(prev) &&
          !_rejectKey.hasMatch(prev) &&
          !_nonItemKey.hasMatch(prev) &&
          !_fragKey.hasMatch(prev) &&
          !_isNoLine(prev)) {
        final pn = prev.replaceAll(_numRe, '').trim();
        if (RegExp(r'[A-Za-z]').allMatches(pn).length >= 3) name = pn;
      }
    }
    // Nama produk betulan: minimal 3 huruf (kode "KK1"/"F1" gugur),
    // tanpa huruf-besar di tengah kata (ciri fragmen OCR rusak).
    if (RegExp(r'[A-Za-z]').allMatches(name).length < 3) continue;
    if (RegExp(r'[a-z][A-Z]').hasMatch(name)) continue;
    final total = _toIdr(nums.last.group(0)!);
    // Harga di bawah Rp100 = cacah/potongan kode, bukan harga barang.
    if (!_okAmount(total)) continue;
    if (items.length >= 8) break;
    items.add('$name ${total!.toInt()}');
    lineItems.add(_splitQty(l, name, total,
        suspicious: amount != null && total > amount));
  }

  // Pajak untuk cek konsistensi (bukan item).
  double? tax;
  for (final l in lines) {
    if (_taxKey.hasMatch(l) && !_isTotalLine(l)) {
      final v = _lastAmount(l);
      if (_okAmount(v)) {
        tax = v;
        break;
      }
    }
  }
  // PRIORITAS (2): subtotal + pajak - diskon ± pembulatan — hanya bila
  // tak ada total eksplisit (grand/total bayar/total belanja). Tak pernah
  // menimpa total yang tertulis eksplisit di struk.
  if (!sawExplicitTotal && grand == null && subtotalVal != null) {
    final cand = subtotalVal +
        (subtotalIncludesTax ? 0 : (tax ?? 0)) -
        (voucher ?? 0) +
        (roundingVal ?? 0);
    if (_okAmount(cand)) amount = cand;
  }

  // Konsistensi: jumlah item (+pajak -diskon) vs total.
  final itemSum = lineItems.fold(0.0, (s, e) => s + e.price);
  final adjSum = itemSum + (tax ?? 0) - (voucher ?? 0);
  final inconsistent = amount != null &&
      lineItems.isNotEmpty &&
      itemsMismatch([adjSum], amount);

  return ReceiptData(
    amount: amount,
    date: date,
    merchant: merchant,
    items: items,
    lineItems: lineItems,
    voucher: voucher,
    confident: amount != null && amount > 0,
    address: _findAddress(lines),
    cashier: _findCashier(lines),
    phone: _findPhone(lines),
    receiptNo: _findReceiptNo(lines),
    time: _findTime(lines),
    payType: _findPayType(lines),
    tax: tax,
    dateFromReceipt: date != null,
    inconsistent: inconsistent,
  );
}

/// Pecah baris item jadi terstruktur. Qty jujur hanya bila terbukti:
/// 2 angka [q, total] (q 1..99) atau [.., q, unit, .., total] dengan
/// unit*q == total. Selain itu qty 1 (tanpa karangan).
ReceiptItem _splitQty(String line, String name, double total,
    {bool suspicious = false}) {
  final nums = [
    for (final m in _numRe.allMatches(line)) _toIdr(m.group(0)!),
  ].whereType<double>().toList();
  if (nums.length == 2) {
    final q = nums[0];
    if (q == q.roundToDouble() &&
        q >= 1 &&
        q <= 99 &&
        (nums[1] - total).abs() < 0.005) {
      return ReceiptItem(
          name: name, qty: q.toInt(), price: total, suspicious: suspicious);
    }
  } else if (nums.length >= 3) {
    for (var i = 0; i + 1 < nums.length; i++) {
      final q = nums[i];
      final unit = nums[i + 1];
      if (q == q.roundToDouble() &&
          q >= 1 &&
          q <= 99 &&
          (unit * q - total).abs() < 0.005) {
        return ReceiptItem(
            name: name, qty: q.toInt(), price: total, suspicious: suspicious);
      }
    }
  }
  return ReceiptItem(name: name, price: total, suspicious: suspicious);
}

/// Alamat: baris jalan/nomor/kecamatan pertama (maks 60 char).
String? _findAddress(List<String> lines) {
  final re = RegExp(
      r'jalan|\bjl\b|kec\.|kel\.|kab\.|kota|no\.\s*\d', caseSensitive: false);
  for (final l in lines) {
    if (l.length > 60 || !_numRe.hasMatch(l) && l.length < 8) continue;
    if (re.hasMatch(l) && !_isTotalLine(l)) {
      return l.length <= 60 ? l : l.substring(0, 60);
    }
  }
  return null;
}

/// Kasir: "Kasir/Server/Operator [:] Nama".
String? _findCashier(List<String> lines) {
  final re = RegExp(
      r'(kasir|server|operator|pramuniaga)\s*:?\s*([A-Za-z .]{2,24})',
      caseSensitive: false);
  for (final l in lines) {
    final m = re.firstMatch(l);
    if (m != null) return m.group(2)!.trim();
  }
  return null;
}

/// Telepon: digit 9-15 tanpa titik (NPWP bertitik tak ikut).
String? _findPhone(List<String> lines) {
  for (final l in lines) {
    final m = RegExp(r'(\+?62|0)8?[0-9][0-9 \-]{6,}').firstMatch(l);
    if (m == null) continue;
    final digits = m.group(0)!.replaceAll(RegExp(r'[\s-]'), '');
    if (RegExp(r'^(\+?62|0)8?\d{7,13}$').hasMatch(digits)) return m.group(0)!.trim();
  }
  return null;
}

/// No struk: "No/Bon/Trx [:] ID" (ID butuh huruf/dash atau ≥4 char
/// supaya "No. 45" alamat tak ikut).
String? _findReceiptNo(List<String> lines) {
  for (final l in lines) {
    if (_dateRe.hasMatch(l)) continue;
    final id = _noId(l);
    if (id == null) continue;
    if (RegExp(r'[A-Za-z-]').hasMatch(id) || id.length >= 4) return id;
  }
  return null;
}

/// True bila baris adalah penanda nomor struk (bukan item belanja).
/// "Bonus 10000" aman: butuh batas kata setelah keyword.
bool _isNoLine(String l) => _noId(l) != null;

String? _noId(String l) {
  final m = RegExp(
          r'(^|\s)(no|nomor|bon|struk|trx|transaksi)\b\s*[.:#]?\s*([A-Za-z0-9][A-Za-z0-9-]{1,19})',
          caseSensitive: false)
      .firstMatch(l);
  return m?.group(3);
}

/// Jam "HH:MM" pertama yang valid.
String? _findTime(List<String> lines) {
  for (final l in lines) {
    final m = RegExp(r'(\d{1,2}):(\d{2})(?::\d{2})?\b').firstMatch(l);
    if (m == null) continue;
    final h = int.tryParse(m.group(1)!) ?? 99;
    final mi = int.tryParse(m.group(2)!) ?? 99;
    if (h <= 23 && mi <= 59) {
      return '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
    }
  }
  return null;
}

/// Jenis bayar dari keyword prioritas (QRIS > Tunai > Debit > E-Money
/// > Transfer > Kartu Kredit). "NON TUNAI" generik tak dipetakan.
String? _findPayType(List<String> lines) {
  bool any(RegExp re) => lines.any((l) => re.hasMatch(l));
  if (any(RegExp(r'qris', caseSensitive: false))) return 'QRIS';
  // "NON TUNAI" generik (tanpa metode jelas) bukan Tunai.
  if (lines.any((l) =>
      RegExp(r'\btunai\b|cash', caseSensitive: false).hasMatch(l) &&
      !RegExp(r'non\s+tunai', caseSensitive: false).hasMatch(l))) {
    return 'Tunai';
  }
  if (any(RegExp(r'debit|edc', caseSensitive: false))) return 'Debit';
  if (any(RegExp(
      r'e-money|emoney|gopay|ovo|dana|shopeepay|linkaja',
      caseSensitive: false))) {
    return 'E-Money';
  }
  if (any(RegExp(r'transfer|m-banking|mobile banking',
      caseSensitive: false))) {
    return 'Transfer';
  }
  if (any(RegExp(r'kartu kredit|credit card|visa|mastercard',
      caseSensitive: false))) {
    return 'Kartu Kredit';
  }
  return null;
}

/// Pecah catatan struk "A · B, C" jadi baris terstruktur
/// [merchant, item...]. Murni agar testable via `dart`.
List<String> receiptNoteLines(String note) => note
    .split('·')
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();

/// Satu baris catatan: merchant + item, maks 200 char.
String receiptNote(ReceiptData d) {  final buf = StringBuffer();
  if (d.merchant != null) buf.write(d.merchant);
  if (d.items.isNotEmpty) {
    if (buf.isNotEmpty) buf.write(' · ');
    buf.write(d.items.take(4).join(', '));
    if (d.items.length > 4) buf.write(' (+${d.items.length - 4})');
  }
  if (d.voucher != null && d.voucher! > 0) {
    buf.write(' · hemat ${d.voucher!.toInt()}');
  }
  final s = buf.toString();
  return s.length <= 200 ? s : s.substring(0, 200);
}

/// Baris tampil replika thermal: urutan = urutan baris asli.
class MirrorLine {
  final String text;
  final double? amount;
  final bool bold;
  final bool centered;
  const MirrorLine(this.text,
      {this.amount, this.bold = false, this.centered = false});
}

final _thanksKey =
    RegExp(r'terima kasih|thanks|selamat belanja', caseSensitive: false);
final _telpKey =
    RegExp(r'telp|telepon|phone|hubungi', caseSensitive: false);
final _ptHead = RegExp(r'^(pt|cv|ud)\b', caseSensitive: false);
final _cashierKey = RegExp(
    r'(kasir|server|operator|pramuniaga)\s*:?\s*([A-Za-z .]{2,24})',
    caseSensitive: false);

/// Angka pertama baris mengandung digit betulan (bukan titik "Jl.").
bool _headHasDigit(String l) {
  final m = _numRe.firstMatch(l);
  return m != null && RegExp(r'\d').hasMatch(m.group(0)!);
}

/// Cermin struk fisik: tiap baris OCR diklasifikasi (header/item/total/
/// polos) dalam URUTAN ASLI; baris sampah dibuang. parseReceipt tak
/// tersentuh (prefill + 43 test lama aman). [pairOrphans]=false untuk
/// layout BBM (harga satuan tak dipasangkan).
List<MirrorLine> mirrorReceipt(String raw, {bool pairOrphans = true}) {
  final lines = _mergeVariants(raw
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList());
  final out = <MirrorLine>[];
  // Antre nama yatim struk 2 kolom (FIFO, display saja, cap 8).
  final pending = <String>[];
  var seenNum = false;
  for (var i = 0; i < lines.length; i++) {
    var l = lines[i];
    // Gabung fragmen seperti loop item ("Nama" / "1 25000").
    // Baris tanggal tak digabung (tanggal milik header, bukan item).
    // Syarat digit: titik singkatan ("Jl.", "No.") bukan angka.
    if (i + 1 < lines.length &&
        !_numRe.hasMatch(l) &&
        _isFragment(l) &&
        _shortHead(lines[i + 1]) &&
        _headHasDigit(lines[i + 1]) &&
        !_isTotalLine(lines[i + 1]) &&
        !_dateRe.hasMatch(lines[i + 1])) {
      l = '$l ${lines[i + 1]}';
      i++;
    }
    // Sampah pasti: kepala PT/CV/UD, kode, digit-telanjang.
    if (_ptHead.hasMatch(l) || _codeKey.hasMatch(l)) continue;
    if (_phoneLine(l) && !_telpKey.hasMatch(l)) continue;
    // Konten header/footer polos: merchant, alamat, kontak, no, kasir,
    // tanggal/jam, ucapan. Merchant Bold. Baris ber-nominal ≥100 bukan
    // merchant (gabungan nama+harga) → jatuh ke cabang item.
    final isMerchant = (_knownMerchant.hasMatch(l) ||
            _merchantLine.hasMatch(l)) &&
        !_okAmount(_lastAmount(l));
    final isAddr = _findAddress([l]) != null;
    final isNo = _isNoLine(l);
    final isCashier = _cashierKey.hasMatch(l);
    final isDate = _dateRe.hasMatch(l) || _dateNameRe.hasMatch(l);
    final isTime = _findTime([l]) != null;
    final isTelp = _telpKey.hasMatch(l);
    final isThanks = _thanksKey.hasMatch(l);
    if (isMerchant ||
        isAddr ||
        isNo ||
        isCashier ||
        isDate ||
        isTime ||
        isTelp ||
        isThanks) {
      out.add(MirrorLine(l, centered: true, bold: isMerchant));
      continue;
    }
    final hasNums = _numRe.hasMatch(l);
    if (hasNums) seenNum = true;
    // Label tender/bayar telanjang: gabung angka murni baris berikut
    // ("TUNAI :" / "50.000"), atau tampil polos. Jangan jadi nama item.
    if (!hasNums &&
        (_cashKey.hasMatch(l) ||
            _changeKey.hasMatch(l) ||
            _payKey.hasMatch(l) ||
            _voucherKey.hasMatch(l))) {
      if (i + 1 < lines.length) {
        final nx = lines[i + 1].trim();
        final nv =
            _pureAmount.hasMatch(nx) ? _lastAmount(nx) : null;
        if (_okAmount(nv)) {
          out.add(MirrorLine(l, amount: nv, bold: false));
          i++;
          continue;
        }
      }
      out.add(MirrorLine(l, centered: true));
      continue;
    }
    if (pairOrphans &&
        !hasNums &&
        _isFragment(l) &&
        (seenNum || !_merchantLine.hasMatch(l))) {
      if (pending.length >= 8) pending.removeAt(0);
      pending.add(l);
    }
    final nums = _numRe.allMatches(l).toList();
    final isTotal = _isTotalLine(l);
    final isTender = _payKey.hasMatch(l) ||
        _cashKey.hasMatch(l) ||
        _changeKey.hasMatch(l) ||
        _voucherKey.hasMatch(l) ||
        _taxKey.hasMatch(l) ||
        _roundingKey.hasMatch(l);
    if ((isTotal || isTender) && !_countKey.hasMatch(l)) {
      var v = _lastAmount(l);
      var label = l;
      // Label tanpa angka ("TOTAL :") + angka di baris berikut.
      if (v == null &&
          i + 1 < lines.length &&
          _pureAmount.hasMatch(lines[i + 1].trim())) {
        v = _lastAmount(lines[i + 1]);
        i++;
      } else if (nums.isNotEmpty) {
        label = l.substring(0, nums.last.start).trim();
      }
      if (v != null && _okAmount(v)) {
        out.add(MirrorLine(label, amount: v, bold: isTotal));
        continue;
      }
      if (v == null && label.isNotEmpty) {
        out.add(MirrorLine(label, bold: isTotal, centered: !isTotal));
        continue;
      }
    }
    // Pasangan 2 kolom: harga yatim + nama menunggu teratas (FIFO).
    // Display saja (tak memengaruhi amount): kolom harga OCR sering
    // turun jadi baris sendiri di bawah namanya.
    final namePart = l.replaceAll(_numRe, '');
    final bareNums =
        RegExp(r'[A-Za-z]').allMatches(namePart).length < 3;
    if (pairOrphans &&
        pending.isNotEmpty &&
        bareNums &&
        !_dateRe.hasMatch(l) &&
        !_phoneLine(l)) {
      final v = _lastAmount(l);
      if (_okAmount(v)) {
        final pname = pending.removeAt(0);
        final pli = _splitQty(l, pname, v!);
        out.add(MirrorLine(
          pli.qty > 1 ? '${pli.name} x${pli.qty}' : pli.name,
          amount: pli.price,
        ));
        continue;
      }
    }
    // Baris item: nama + nominal, qty terbukti.
    // Tender/pajak/pembulatan bukan item.
    if (_fragKey.hasMatch(l) ||
        _rejectKey.hasMatch(l) ||
        _nonItemKey.hasMatch(l)) {
      continue;
    }
    if (nums.isEmpty) continue;
    final name = l.substring(0, nums.first.start).trim();
    if (RegExp(r'[A-Za-z]').allMatches(name).length < 3) continue;
    if (RegExp(r'[a-z][A-Z]').hasMatch(name)) continue;
    final total = _toIdr(nums.last.group(0)!);
    if (!_okAmount(total)) continue;
    final li = _splitQty(l, name, total!);
    out.add(MirrorLine(
      li.qty > 1 ? '${li.name} x${li.qty}' : li.name,
      amount: li.price,
    ));
  }
  return out;
}

/// Pecah satu item "Nama Produk 25000" menjadi nama + nominal.
/// Tanpa angka akhir = (teks, 0). Dipakai layout struk hasil scan.
({String name, double amount}) splitReceiptItem(String item) {
  final m =
      RegExp(r'^(.*\S)\s+(\d+(?:\.\d+)?)\s*$').firstMatch(item.trim());
  if (m == null) return (name: item.trim(), amount: 0);
  return (name: m.group(1)!.trim(), amount: double.tryParse(m.group(2)!) ?? 0);
}
