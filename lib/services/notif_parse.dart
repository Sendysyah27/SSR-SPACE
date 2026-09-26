import 'package:crypto/crypto.dart';

import 'dart:convert';

/// Cocok `Rp88.655`, `Rp 10.800,00`, `IDR 88,655.00`, `IDR88,655`.
/// Grup wajib berakhir digit agar titik/koma akhir kalimat
/// (`Rp. 17.000. Ref`) tidak ikut tertangkap.
final _amountRe = RegExp(
  r'(?:Rp|IDR)\.?\s*([\d](?:[\d.,]*\d)?)',
  caseSensitive: false,
);

/// Normalisasi angka:
/// - `88.655` / `1.234.567` → gaya Indonesia (titik = ribuan)
/// - `88,655.00` → gaya barat (koma = ribuan, titik = desimal)
/// - `10.800,00` → titik ribuan + koma desimal
/// - `10,80` → desimal; `88,655` → ribuan
double? _normalizeAmount(String raw) {
  final g = raw.replaceAll(RegExp(r'[^\d.,]'), '');
  if (g.isEmpty) return null;
  final hasDot = g.contains('.');
  final hasComma = g.contains(',');
  String normalized;
  if (hasDot && hasComma) {
    if (g.lastIndexOf('.') > g.lastIndexOf(',')) {
      normalized = g.replaceAll(',', '');
    } else {
      normalized = g.replaceAll('.', '').replaceAll(',', '.');
    }
  } else if (hasComma) {
    final parts = g.split(',');
    if (parts.length == 2 && parts[1].length <= 2 && parts[1].isNotEmpty) {
      normalized = '${parts[0]}.${parts[1]}';
    } else {
      normalized = g.replaceAll(',', '');
    }
  } else if (hasDot) {
    final parts = g.split('.');
    final allThousands =
        parts.length > 1 && parts.skip(1).every((p) => p.length == 3);
    normalized = allThousands ? g.replaceAll('.', '') : g;
  } else {
    normalized = g;
  }
  return double.tryParse(normalized);
}

double? parseNotifAmount(String text) {
  final m = _amountRe.firstMatch(text);
  if (m == null) return null;
  return _normalizeAmount(m.group(1)!);
}

const _inKeys = [
  'dana masuk',
  'uang masuk',
  'telah diterima',
  'diterima sebesar',
  'pengkreditan',
  'top up masuk',
  'top up',
  'topup',
  'refund',
  'dana kembali',
  'cashback',
  'transfer masuk',
  'masuk sebesar',
  'telah masuk',
  'gaji telah',
  'pemasukan',
  'menerima',
  'diterima',
  'berhasil top up',
  'isi saldo',
  'isi ulang',
  'cash in',
  'cashin',
];

const _outKeys = [
  'berhasil ditransfer',
  'transfer berhasil',
  'pembayaran berhasil',
  'berhasil dibayar',
  'telah dibayar',
  'berhasil terkirim',
  'dana keluar',
  'saldo berkurang',
  'pendebetan',
  'penarikan berhasil',
  'pembelian berhasil',
  'qris berhasil',
  'berhasil ditarik',
  'pengeluaran',
  'penarikan',
  'pembayaran',
  'dibebankan',
];

/// Cocokkan frasa multi-kata: kata berurutan, boleh ada jeda
/// (nominal / kata penghubung) di antaranya, mis. `Transfer Rp50.000 berhasil`.
bool _phraseHit(String t, String phrase) {
  if (!phrase.contains(' ')) return t.contains(phrase);
  final words = phrase.split(RegExp(r'\s+'));
  var idx = 0;
  for (final w in words) {
    final i = t.indexOf(w, idx);
    if (i < 0) return false;
    idx = i + w.length;
  }
  return true;
}

String? classifyNotif(String text) {
  final t = text.toLowerCase();
  final isIn = _inKeys.any((k) => _phraseHit(t, k));
  final isOut = _outKeys.any((k) => _phraseHit(t, k));
  if (isIn && isOut) return null;
  if (isIn) return 'in';
  if (isOut) return 'out';
  return null;
}

/// Hash dedup per hari + isi notif. Notif identik di hari beda tetap bisa dicatat.
String notifHash(String package, String title, String content, {DateTime? at}) {
  final day = (at ?? DateTime.now()).toIso8601String().substring(0, 10);
  return sha256
      .convert(utf8.encode('$day|$package|$title|$content'))
      .toString();
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class WatchedApp {
  final String label;
  final List<String> packagePrefixes;
  const WatchedApp(this.label, this.packagePrefixes);

  bool matches(String package) {
    for (final p in packagePrefixes) {
      final q = p.toLowerCase();
      if (package == q || package.startsWith('$q.')) return true;
    }
    return false;
  }
}

/// Allowlist package (prefix titik / exact), bukan substring bebas.
/// Urutan penting: myBCA sebelum BCA.
const watchedApps = [
  WatchedApp('myBCA', ['com.bca.mybca']),
  WatchedApp('BCA', ['com.bankcentralasia', 'com.bca.main', 'com.bca']),
  WatchedApp('Livin Mandiri', ['com.mandiri.mobile', 'com.bankmandiri']),
  WatchedApp('DANA', ['id.dana']),
  WatchedApp('OVO', ['com.vnoo.ovo', 'com.ovo', 'ovo.id']),
  WatchedApp('GoPay', ['com.gojek.app', 'com.gojek.gojek', 'com.gojek.gopay']),
  WatchedApp('ShopeePay', ['com.shopee', 'com.shopeepay']),
  WatchedApp('SeaBank', [
    'com.seabank',
    'id.co.seabank',
    'id.co.bankbkemobile',
    'id.co.bankbke',
  ]),
  WatchedApp('BRI', ['com.bri.brimo', 'id.co.bri.brimo', 'com.bri.browser']),
  WatchedApp('BNI', ['com.bni', 'id.co.bni', 'src.com.bni']),
  WatchedApp('BTN', ['com.btn', 'id.co.btn']),
  WatchedApp('Jenius', ['com.btpn', 'id.co.btpn']),
  WatchedApp('Jago', ['id.co.jago', 'com.bankjago', 'com.jago.digitalBanking']),
  WatchedApp('Blu', ['com.bca.digital', 'id.co.bca.blu', 'com.bcadigital.blu']),
  WatchedApp('CIMB', ['com.cimb', 'com.octo', 'id.co.cimbniaga']),
  WatchedApp('KEB Hana', ['id.co.kebhana', 'co.id.myhana.app']),
  WatchedApp('ISAKU', ['com.isaku']),
];

String? matchWatchedApp(String package) {
  final p = package.trim().toLowerCase();
  if (p.isEmpty) return null;
  for (final app in watchedApps) {
    if (app.matches(p)) return app.label;
  }
  return null;
}
