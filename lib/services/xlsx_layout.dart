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
