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

String notifHash(String package, String title, String content) =>
    sha256.convert(utf8.encode('$package|$title|$content')).toString();

class WatchedApp {
  final String label;
  final List<String> keys;
  const WatchedApp(this.label, this.keys);
}

const watchedApps = [
  WatchedApp('myBCA', ['mybca']),
  WatchedApp('BCA', ['com.bca']),
  WatchedApp('Livin Mandiri', ['mandiri', 'livin']),
  WatchedApp('DANA', ['dana']),
  WatchedApp('OVO', ['ovo']),
  WatchedApp('GoPay', ['gojek', 'gopay']),
  WatchedApp('ShopeePay', ['shopee']),
  WatchedApp('SeaBank', ['seabank']),
  WatchedApp('BRI', ['brimo', '.bri']),
  WatchedApp('BNI', ['bni']),
  WatchedApp('BTN', ['btn']),
  WatchedApp('Jenius', ['jenius']),
  WatchedApp('Jago', ['jago']),
  WatchedApp('Blu', ['blu']),
  WatchedApp('CIMB', ['cimb', 'octo']),
  WatchedApp('KEB Hana', ['keb', 'hana', 'bankbke']),
];

String? matchWatchedApp(String package) {
  final p = package.toLowerCase();
  for (final app in watchedApps) {
    if (app.keys.any(p.contains)) return app.label;
  }
  return null;
}
