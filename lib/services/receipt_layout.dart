// Susun spasial baris OCR (pola opensource savingor/receipt_recognition).
//
// ML Kit mengembalikan blocks -> lines + boundingBox; teks datar
// (`out.text`) menghancurkan kolom (nama | harga jadi baris terpisah).
// Di sini: kelompok sebaris (tengah Y ± setengah tinggi), urut Y lalu X,
// gabung sebaris. Murni Dart (tanpa dep mlkit) supaya TDD via `dart`.
// Tanpa geometri (box null) pemanggil tetap pakai teks datar.
class OcrBox {
  final String text;
  final int left;
  final int top;
  final int right;
  final int bottom;
  const OcrBox(this.text, this.left, this.top, this.right, this.bottom);

  int get cy => (top + bottom) ~/ 2;
  int get h => bottom - top;
}

List<String> spatialLines(List<OcrBox> boxes) {
  final rows = <List<OcrBox>>[];
  final sorted = [for (final b in boxes) if (b.text.trim().isNotEmpty) b]
    ..sort((a, b) => a.top.compareTo(b.top));
  for (final box in sorted) {
    var placed = false;
    for (final row in rows) {
      final first = row.first;
      final tol = (first.h > box.h ? first.h : box.h) ~/ 2;
      if ((box.cy - first.cy).abs() <= tol) {
        row.add(box);
        placed = true;
        break;
      }
    }
    if (!placed) rows.add([box]);
  }
  return [
    for (final row in rows)
      (row..sort((a, b) => a.left.compareTo(b.left)))
          .map((b) => b.text.trim())
          .join(' '),
  ];
}
