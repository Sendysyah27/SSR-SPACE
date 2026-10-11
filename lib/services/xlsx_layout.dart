// Lebar kolom .xlsx dari isi sel (satuan lebar Excel ~= karakter).
// Murni Dart: builder (report_xlsx) memanggil ini per kolom.

// Lebar = teks terpanjang + pad, dijepit [min, max].
double xlsxFitWidth(
  Iterable<String> cells, {
  double min = 10,
  double max = 50,
  double pad = 2,
}) {
  var m = 0;
  for (final c in cells) {
    final len = c.runes.length;
    if (len > m) m = len;
  }
  return (m + pad).clamp(min, max).toDouble();
}

/// Nama bulan Indonesia singkat untuk tanggal full struk/laporan.
const idMonthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// '11 Okt 2026' — deterministik di semua viewer (tak ikut locale HP).
String idFullDate(DateTime d) => '${d.day} ${idMonthShort[d.month - 1]} ${d.year}';
