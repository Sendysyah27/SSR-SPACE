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
final _pureAmount = RegExp(r'^[Rp\s.:]*\(?[\d.,]+\)?\s*$');

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
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    final isTotal = _isTotalLine(l);
    if (!isTotal || _rejectKey.hasMatch(l)) {
      // Baris gabung ("TOTAL 41.250 TUNAI 50.000"): ambil angka sebelum
      // ekor tunai/kembali, jangan buang barisnya.
      if (isTotal && _tenderKey.hasMatch(l)) {
        final cut = _tenderKey.firstMatch(l)!.start;
        final v = _lastAmount(l.substring(0, cut));
        if (v != null && v > 0 && (amount == null || v > amount)) {
          amount = v;
        }
      }
      continue;
    }
    var v = _lastAmount(l);
    // Total & angka di baris terpisah ("TOTAL :" / "41.250"): intip baris
    // berikut bila murni angka (bukan item, bukan tunai/kembali).
    if (v == null && _numRe.allMatches(l).isEmpty && i + 1 < lines.length) {
      final nx = lines[i + 1];
      if (!_rejectKey.hasMatch(nx) && _pureAmount.hasMatch(nx)) {
        v = _lastAmount(nx);
      }
    }
    if (v != null && v > 0 && (amount == null || v > amount)) amount = v;
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
    if (rpLines.length == 1) amount = _lastAmount(rpLines.first);
  }

  DateTime? date;
  for (final l in lines) {
    for (final m in _dateRe.allMatches(l)) {
      final d = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      var y = int.tryParse(m.group(3)!);
      if (d == null || mo == null || y == null) continue;
      if (y < 100) y += 2000;
      if (d < 1 || d > 31 || mo < 1 || mo > 12 || y < 2000 || y > 2100) {
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
      if (_merchantLine.hasMatch(l) && _numRe.allMatches(l).length <= 1) {
        return l;
      }
    }
    return null;
  }();

  final items = <String>[];
  double? voucher;
  for (final l in lines) {
    // Voucher/diskon: catat nominalnya, jangan jadi item.
    if (_voucherKey.hasMatch(l) && !_totalKey.hasMatch(l)) {
      final v = _lastAmount(l);
      if (v != null) voucher = (voucher ?? 0) + v.abs();
      continue;
    }
    if (_totalKey.hasMatch(l) ||
        _rejectKey.hasMatch(l) ||
        _dateRe.hasMatch(l)) {
      continue;
    }
    final nums = _numRe.allMatches(l).toList();
    if (nums.isEmpty) continue;
    final name = l.substring(0, nums.first.start).trim();
    if (name.length < 3) continue;
    final total = _toIdr(nums.last.group(0)!);
    if (total == null || total <= 0) continue;
    if (items.length >= 8) break;
    items.add('$name ${total.toInt()}');
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
String receiptNote(ReceiptData d) {
  final buf = StringBuffer();
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
