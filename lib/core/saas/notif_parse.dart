import 'package:crypto/crypto.dart';
import 'dart:convert';

final _amountRe = RegExp(r'Rp\.?\s?([\d\.]+(?:,\d{1,2})?)');

double? parseNotifAmount(String text) {
  final m = _amountRe.firstMatch(text);
  if (m == null) return null;
  final cleaned = m.group(1)!.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(cleaned);
}

const _inKeys = [
  'dana masuk', 'uang masuk', 'telah diterima', 'diterima sebesar',
  'pengkreditan', 'top up masuk', 'refund', 'dana kembali', 'cashback',
  'transfer masuk', 'masuk sebesar', 'telah masuk', 'gaji telah',
];

const _outKeys = [
  'berhasil ditransfer', 'transfer berhasil', 'pembayaran berhasil',
  'berhasil dibayar', 'telah dibayar', 'berhasil terkirim',
  'dana keluar', 'saldo berkurang', 'pendebetan', 'penarikan berhasil',
  'pembelian berhasil', 'qris berhasil', 'berhasil ditarik',
];

String? classifyNotif(String text) {
  final t = text.toLowerCase();
  final isIn = _inKeys.any(t.contains);
  final isOut = _outKeys.any(t.contains);
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
      if (package == p || package.startsWith('$p.')) return true;
    }
    return false;
  }
}

/// Allowlist package (prefix titik / exact), bukan substring bebas.
/// Urutan penting: myBCA sebelum BCA.
const watchedApps = [
  WatchedApp('myBCA', ['com.bca.mybca']),
  WatchedApp('BCA', ['com.bankcentralasia', 'com.bca.main']),
  WatchedApp('Livin Mandiri', ['com.mandiri.mobile', 'com.bankmandiri']),
  WatchedApp('DANA', ['id.dana']),
  WatchedApp('OVO', ['com.vnoo.ovo', 'com.ovo']),
  WatchedApp('GoPay', ['com.gojek.app', 'com.gojek.gojek']),
  WatchedApp('ShopeePay', ['com.shopee']),
  WatchedApp('SeaBank', ['com.seabank', 'id.co.seabank']),
  WatchedApp('BRI', ['com.bri.brimo', 'id.co.bri.brimo', 'com.bri.browser']),
  WatchedApp('BNI', ['com.bni', 'id.co.bni']),
  WatchedApp('BTN', ['com.btn', 'id.co.btn']),
  WatchedApp('Jenius', ['com.btpn', 'id.co.btpn']),
  WatchedApp('Jago', ['id.co.jago', 'com.bankjago']),
  WatchedApp('Blu', ['com.bca.digital', 'id.co.bca.blu']),
  WatchedApp('CIMB', ['com.cimb', 'com.octo']),
  WatchedApp('KEB Hana', ['id.co.bankbke', 'id.co.kebhana']),
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
