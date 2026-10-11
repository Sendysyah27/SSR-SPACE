// Parser struk belanja dari teks OCR mentah (ML Kit on-device).
//
// File SENGAJA tanpa import apa pun supaya bisa diverifikasi via `dart`
// murni di Termux. UI hanya memanggil parseReceipt; validasi akhir tetap
// di TransactionService saat simpan.

/// Hasil urai struk. `confident` true hanya bila total eksplisit ketemu.
class ReceiptData {
  final double? amount;
  final DateTime? date;
  final String? merchant;
  final List<String> items;
  final double? voucher;
  final bool confident;
  const ReceiptData({
    this.amount,
    this.date,
    this.merchant,
    this.items = const [],
    this.voucher,
    this.confident = false,
  });
}

final _totalKey =
    RegExp(r'total|tot\s|jumlah|bayar|grand', caseSensitive: false);
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
  r'server|wifi|password|username|user\s?name|login|order|jalan|\bjl\b|kec\b|kab\b|kel\b|npwp|trxid|member|terima|kasih|layanan|stamp|poin|struk|transaksi|whatsapp|whats|tlp|telp|telepon|hubungi|\bhp\b|http|www|@',
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

/// Baris total toleran OCR: spasi nyasar ("TOTA L") + 0/O ("T0TAL").
bool _isTotalLine(String l) {
  if (_totalKey.hasMatch(l)) return true;
  final n = l.toLowerCase().replaceAll(' ', '').replaceAll('0', 'o');
  return n.contains('total');
}
final _rejectKey = RegExp(
  r'kembali|tunai|dpp|ppn|harga jual|purchase|hemat|trxid',
  caseSensitive: false,
);
final _numRe = RegExp(r'\(?[\d.,]+\)?');
final _dateRe = RegExp(r'(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})');
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

/// Urut prioritas: baris kunci TOTAL dulu, abaikan baris pengecoh.
ReceiptData parseReceipt(String raw) {
  final lines = raw
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return const ReceiptData();

  double? amount;
  double? grand;
  var seenTotal = false;
  var seenGrandMangled = false;
  // Suara angka nyasar (baris murni angka, bukan pengecoh, bukan "1 25000").
  final votes = <double, int>{};
  for (final l in lines) {
    if (_rejectKey.hasMatch(l) || !_pureAmount.hasMatch(l)) continue;
    if (RegExp(r'^\d+\s+\d').hasMatch(l)) continue;
    final v = _lastAmount(l);
    if (v != null) votes[v] = (votes[v] ?? 0) + 1;
  }
  final singleDetached = votes.length == 1 && votes.values.first == 1;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    final isTotal = _isTotalLine(l);
    if (isTotal) seenTotal = true;
    // "TOTAL ITEM: 2" = cacah barang, bukan uang.
    if (isTotal && _countKey.hasMatch(l)) continue;
    if (!isTotal || _rejectKey.hasMatch(l)) {
      // Baris gabung ("TOTAL 41.250 TUNAI 50.000"): ambil angka sebelum
      // ekor tunai/kembali, jangan buang barisnya.
      if (isTotal && _tenderKey.hasMatch(l)) {
        final cut = _tenderKey.firstMatch(l)!.start;
        final v = _lastAmount(l.substring(0, cut));
        if (_okAmount(v) && (amount == null || v! > amount)) {
          amount = v;
        }
      } else if (isTotal && _grandKey.hasMatch(l)) {
        seenGrandMangled = true;
      }
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
    }
  }
  // Grand total menang atas subtotal/total (nominal akhir yang dibayar).
  if (grand != null) amount = grand;
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
  double? voucher;
  for (var i = 0; i < lines.length; i++) {
    var l = lines[i];
    // Voucher/diskon: catat nominalnya, jangan jadi item.
    if (_voucherKey.hasMatch(l) && !_totalKey.hasMatch(l)) {
      final v = _lastAmount(l);
      if (v != null) voucher = (voucher ?? 0) + v.abs();
      continue;
    }
    // Gabung baris terfragmentasi ("Kopi Kenangan Mantan" / "1 25000").
    if (i + 1 < lines.length &&
        !_numRe.hasMatch(l) &&
        _isFragment(l) &&
        _shortHead(lines[i + 1])) {
      l = '$l ${lines[i + 1]}';
      i++;
    }
    if (_isTotalLine(l) ||
        _rejectKey.hasMatch(l) ||
        _fragKey.hasMatch(l) ||
        _phoneLine(l) ||
        _dateRe.hasMatch(l)) {
      continue;
    }
    final nums = _numRe.allMatches(l).toList();
    if (nums.isEmpty) continue;
    final name = l.substring(0, nums.first.start).trim();
    // Nama produk betulan: minimal 3 huruf (kode "KK1"/"F1" gugur),
    // tanpa huruf-besar di tengah kata (ciri fragmen OCR rusak).
    if (RegExp(r'[A-Za-z]').allMatches(name).length < 3) continue;
    if (RegExp(r'[a-z][A-Z]').hasMatch(name)) continue;
    final total = _toIdr(nums.last.group(0)!);
    // Harga di bawah Rp100 = cacah/potongan kode, bukan harga barang.
    if (!_okAmount(total)) continue;
    if (items.length >= 8) break;
    items.add('$name ${total!.toInt()}');
  }

  return ReceiptData(
    amount: amount,
    date: date,
    merchant: merchant,
    items: items,
    voucher: voucher,
    confident: amount != null && amount > 0,
  );
}

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

/// Pecah satu item "Nama Produk 25000" menjadi nama + nominal.
/// Tanpa angka akhir = (teks, 0). Dipakai layout struk hasil scan.
({String name, double amount}) splitReceiptItem(String item) {
  final m =
      RegExp(r'^(.*\S)\s+(\d+(?:\.\d+)?)\s*$').firstMatch(item.trim());
  if (m == null) return (name: item.trim(), amount: 0);
  return (name: m.group(1)!.trim(), amount: double.tryParse(m.group(2)!) ?? 0);
}
