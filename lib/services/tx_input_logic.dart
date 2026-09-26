/// Logika murni input transaksi: numpad nominal + rakit tanggal/jam.
///
/// File ini SENGAJA tanpa import Flutter/package apa pun supaya bisa
/// diverifikasi via `dart` murni di Termux (tanpa `flutter test`).
/// Widget (`tx_numpad.dart`, `tx_input_sheet.dart`) hanya memanggil
/// fungsi di sini; formatting tampilan ke mata uang tetap di
/// `CurrencyService.format` (sisi widget, sudah sadar kurs + mask).

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

/// Tambah ketukan ke buffer digit. [key] digit '0'..'9' atau '000'
/// (tombol tiga-nol ala e-wallet). Kunci asing diabaikan.
/// Buffer dibatasi [maxLen] digit; buffer '0' tunggal tidak menumpuk nol.
String numpadAppend(String current, String key, {int maxLen = 15}) {
  if (key == '000') {
    if (current.isEmpty || current == '0') return '0';
    final room = maxLen - current.length;
    if (room <= 0) return current;
    return current + '000'.substring(0, room >= 3 ? 3 : room);
  }
  if (key.length != 1) return current;
  final c = key.codeUnitAt(0);
  if (c < 48 || c > 57) return current;
  if (current.isEmpty) return key == '0' ? '0' : key;
  if (current == '0') return key == '0' ? '0' : key;
  if (current.length >= maxLen) return current;
  return current + key;
}

/// Hapus satu digit terakhir. Buffer kosong tetap kosong.
String numpadBackspace(String current) {
  if (current.isEmpty) return '';
  return current.substring(0, current.length - 1);
}

/// Buffer digit → nominal mayor mata uang tampil.
/// [dec] = jumlah desimal mata uang tampil (IDR/JPY = 0, USD = 2).
/// Bila [dec] > 0, digit dianggap satuan minor (sen) supaya edit
/// non-IDR tetap eksak (1050 + dec 2 → 10.50, bukan 1050).
double majorFromDigits(String digits, {int dec = 0}) {
  if (digits.isEmpty) return 0;
  final minor = double.tryParse(digits) ?? 0;
  if (dec <= 0) return minor;
  return minor / _pow10(dec);
}

/// Nominal mayor tampil → buffer digit awal (untuk mode edit).
String digitsFromMajor(double major, {int dec = 0}) {
  if (major <= 0) return '';
  if (dec <= 0) return major.round().toString();
  return (major * _pow10(dec)).round().toString();
}

/// DateTime → 'YYYY-MM-DD' (kolom `date` Postgres).
String txYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Rakit pasangan simpan untuk insert/update:
/// - `date` selalu tanggal pilihan (default hari ini, bukan server now).
/// - `createdAt` (kolom `created_at`) hanya diisi bila jam dipilih —
///   gabungan tanggal + jam presisi menit, format ISO lokal
///   ('2026-09-26T18:34:00'). Null berarti "pakai now() server",
///   jadi tanpa migration kolom baru alur lama tak berubah.
({String date, String? createdAt}) txWhen(
  DateTime day, {
  int? hour,
  int? minute,
}) {
  final date = txYmd(day);
  if (hour == null || minute == null) {
    return (date: date, createdAt: null);
  }
  final hh = hour.toString().padLeft(2, '0');
  final mm = minute.toString().padLeft(2, '0');
  return (date: date, createdAt: '${date}T$hh:$mm:00');
}

/// Urai `created_at` simpanan → jam+menit untuk mengisi ulang
/// time picker saat mode edit. Gagal urai / kosong → null
/// (diperlakukan sebagai "jam tak diisi").
({int hour, int minute})? txCreatedAtTime(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    final dt = DateTime.parse(iso);
    return (hour: dt.hour, minute: dt.minute);
  } catch (_) {
    return null;
  }
}
