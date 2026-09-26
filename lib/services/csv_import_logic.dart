// Logika murni import CSV: deteksi delimiter + parse preview per baris.
//
// File ini SENGAJA tanpa import Flutter/package apa pun supaya bisa
// diverifikasi via `dart` murni di Termux (tanpa `flutter test`).
// UI import (Task 6) hanya memanggil fungsi di sini; validasi akhir
// tetap di TransactionService saat simpan.

class CsvImportRow {
  final String date;
  final String type;
  final String walletName;
  final String toWalletName;
  final String category;
  final String note;
  final double amount;
  final int lineNo;
  const CsvImportRow({
    required this.date,
    required this.amount,
    required this.type,
    required this.walletName,
    this.toWalletName = '',
    this.category = '',
    this.note = '',
    required this.lineNo,
  });
}

class CsvImportError {
  final int lineNo;
  final String message;
  const CsvImportError(this.lineNo, this.message);
}

class CsvImportPreview {
  final List<CsvImportRow> rows;
  final List<CsvImportError> errors;
  const CsvImportPreview(this.rows, this.errors);
}

/// Tebak pemisah kolom: ',' bila koma >= titik-koma, else ';' —
/// kecuali tab yang terbanyak, maka '\t'.
String detectDelimiter(String text) {
  var commas = 0;
  var semis = 0;
  var tabs = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c == 44) {
      commas++;
    } else if (c == 59) {
      semis++;
    } else if (c == 9) {
      tabs++;
    }
  }
  if (tabs > commas && tabs > semis) return '\t';
  if (commas >= semis) return ',';
  return ';';
}

/// Nominal teks → double. Buang 'Rp'/'IDR'/spasi; dukung format ID
/// (1.234,50) vs EN (1,234.50): bila koma dan titik sama-sama ada,
/// yang terakhir muncul adalah desimal. Koma saja = desimal;
/// titik saja = desimal bila tepat 2 digit di akhir, else ribuan.
/// Throw FormatException bila tak terbaca atau <= 0.
double parseAmountValue(String s) {
  var t = s.trim().toUpperCase();
  t = t.replaceAll('IDR', '').replaceAll('RP', '');
  t = t.replaceAll(RegExp(r'\s+'), '');
  if (t.isEmpty) throw FormatException('nominal kosong: "$s"');
  final hasComma = t.contains(',');
  final hasDot = t.contains('.');
  String norm;
  if (hasComma && hasDot) {
    if (t.lastIndexOf(',') > t.lastIndexOf('.')) {
      norm = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      norm = t.replaceAll(',', '');
    }
  } else if (hasComma) {
    norm = t.replaceAll(',', '.');
  } else if (hasDot) {
    norm = RegExp(r'\.\d{2}$').hasMatch(t) ? t : t.replaceAll('.', '');
  } else {
    norm = t;
  }
  final v = double.tryParse(norm);
  if (v == null) throw FormatException('nominal tak terbaca: "$s"');
  if (v <= 0) throw FormatException('nominal harus > 0: "$s"');
  return v;
}

/// Tanggal teks → 'yyyy-MM-dd'. Terima dd/MM/yyyy, dd-MM-yyyy,
/// yyyy-MM-dd, yyyyMMdd. Validasi bulan 1-12 dan hari 1-31 saja
/// (tanpa cek kabisat). Throw FormatException bila tak dikenal.
String parseDateValue(String s) {
  final t = s.trim();
  final ddMmYyyySlash = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(t);
  if (ddMmYyyySlash != null) {
    return _ymd(
      ddMmYyyySlash.group(3)!,
      ddMmYyyySlash.group(2)!,
      ddMmYyyySlash.group(1)!,
      s,
    );
  }
  final ddMmYyyyDash = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(t);
  if (ddMmYyyyDash != null) {
    return _ymd(
      ddMmYyyyDash.group(3)!,
      ddMmYyyyDash.group(2)!,
      ddMmYyyyDash.group(1)!,
      s,
    );
  }
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(t);
  if (iso != null) {
    return _ymd(iso.group(1)!, iso.group(2)!, iso.group(3)!, s);
  }
  final plain = RegExp(r'^(\d{8})$').firstMatch(t);
  if (plain != null) {
    final d = plain.group(1)!;
    return _ymd(d.substring(0, 4), d.substring(4, 6), d.substring(6, 8), s);
  }
  throw FormatException('tanggal tak dikenal: "$s"');
}

String _ymd(String y, String m, String d, String raw) {
  final mi = int.tryParse(m) ?? 0;
  final di = int.tryParse(d) ?? 0;
  if (mi < 1 || mi > 12 || di < 1 || di > 31) {
    throw FormatException('tanggal tak valid: "$raw"');
  }
  return '$y-${m.padLeft(2, '0')}-${d.padLeft(2, '0')}';
}

/// Jenis teks → 'in' | 'out' | 'transfer'. Throw bila tak dikenal.
String parseTypeValue(String s) {
  switch (s.trim().toLowerCase()) {
    case 'masuk':
    case 'in':
    case 'income':
    case 'pemasukan':
      return 'in';
    case 'keluar':
    case 'out':
    case 'expense':
    case 'pengeluaran':
    case 'belanja':
      return 'out';
    case 'transfer':
    case 'tf':
    case 'mutasi':
      return 'transfer';
    default:
      throw FormatException('jenis tak dikenal: "$s"');
  }
}

/// Netralkan sel formula spreadsheet: bila diawali =,+,-,@ (setelah
/// trim), prefix apostrof supaya tak dieksekusi saat dibuka di Excel.
String neutralizeFormula(String s) {
  final t = s.trimLeft();
  if (t.isEmpty) return s;
  final c = t.codeUnitAt(0);
  if (c == 61 || c == 43 || c == 45 || c == 64) return "'$s";
  return s;
}

List<String> _splitCsvLine(String line, String delim) {
  final cells = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buf.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == delim) {
      cells.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  cells.add(buf.toString());
  return cells;
}

String _cell(List<String> cells, int idx) {
  if (idx < 0 || idx >= cells.length) return '';
  var c = cells[idx].trim();
  if (c.length >= 2 && c.startsWith('"') && c.endsWith('"')) {
    c = c.substring(1, c.length - 1).replaceAll('""', '"').trim();
  }
  return c;
}

bool _isFormula(String s) {
  final t = s.trimLeft();
  if (t.isEmpty) return false;
  final c = t.codeUnitAt(0);
  return c == 61 || c == 43 || c == 45 || c == 64;
}

/// Parse teks CSV jadi preview baris + error per baris. Header
/// case-insensitive (lowercase+trim) dengan alias ID/EN; wajib ada
/// kolom tanggal + nominal + jenis. Baris kosong dilewati diam-diam;
/// sel formula dinetralkan untuk field teks, tapi nominal formula
/// = error baris. Tak pernah throw untuk error data.
CsvImportPreview parseCsvPreview(String text) {
  final delim = detectDelimiter(text);
  final lines = text.split('\n');
  if (lines.isEmpty || lines.every((l) => l.trim().isEmpty)) {
    return const CsvImportPreview([], [
      CsvImportError(0, 'header kurang: tanggal, nominal, jenis'),
    ]);
  }
  final header = _splitCsvLine(
    lines.first,
    delim,
  ).map((h) => h.trim().toLowerCase()).toList();
  var iTanggal = -1;
  var iNominal = -1;
  var iJenis = -1;
  var iDompet = -1;
  var iKeDompet = -1;
  var iKategori = -1;
  var iCatatan = -1;
  for (var i = 0; i < header.length; i++) {
    switch (header[i]) {
      case 'tanggal':
      case 'date':
        iTanggal = i;
      case 'nominal':
      case 'amount':
        iNominal = i;
      case 'jenis':
      case 'type':
        iJenis = i;
      case 'dompet':
      case 'wallet':
        iDompet = i;
      case 'ke_dompet':
      case 'to_wallet':
      case 'ke dompet':
        iKeDompet = i;
      case 'kategori':
      case 'category':
        iKategori = i;
      case 'catatan':
      case 'note':
        iCatatan = i;
    }
  }
  final missing = <String>[];
  if (iTanggal < 0) missing.add('tanggal');
  if (iNominal < 0) missing.add('nominal');
  if (iJenis < 0) missing.add('jenis');
  if (missing.isNotEmpty) {
    return CsvImportPreview([], [
      CsvImportError(0, 'header kurang: ${missing.join(', ')}'),
    ]);
  }
  final rows = <CsvImportRow>[];
  final errors = <CsvImportError>[];
  for (var li = 1; li < lines.length; li++) {
    final line = lines[li];
    if (line.trim().isEmpty) continue;
    final lineNo = li + 1;
    final cells = _splitCsvLine(line, delim);
    if (cells.every((c) => c.trim().isEmpty)) continue;
    final rawDate = _cell(cells, iTanggal);
    final rawAmount = _cell(cells, iNominal);
    final rawType = _cell(cells, iJenis);
    String date;
    try {
      date = parseDateValue(rawDate);
    } on FormatException catch (e) {
      errors.add(CsvImportError(lineNo, e.message));
      continue;
    }
    double amount;
    if (_isFormula(rawAmount)) {
      errors.add(
        CsvImportError(lineNo, 'nominal formula ditolak: "$rawAmount"'),
      );
      continue;
    }
    try {
      amount = parseAmountValue(rawAmount);
    } on FormatException catch (e) {
      errors.add(CsvImportError(lineNo, e.message));
      continue;
    }
    String type;
    try {
      type = parseTypeValue(rawType);
    } on FormatException catch (e) {
      errors.add(CsvImportError(lineNo, e.message));
      continue;
    }
    rows.add(
      CsvImportRow(
        date: date,
        amount: amount,
        type: type,
        walletName: neutralizeFormula(_cell(cells, iDompet)),
        toWalletName: neutralizeFormula(_cell(cells, iKeDompet)),
        category: neutralizeFormula(_cell(cells, iKategori)),
        note: neutralizeFormula(_cell(cells, iCatatan)),
        lineNo: lineNo,
      ),
    );
  }
  return CsvImportPreview(rows, errors);
}
