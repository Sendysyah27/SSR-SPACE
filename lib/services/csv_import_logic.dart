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

/// Tebak pemisah kolom: koma bila koma >= titik-koma, else ';',
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
    // Titik saja: pecahan nol semua berarti '15000.0'/'.00' (desimal ala
    // ekspor) -> buang titik + pecahan; tapi '.000' = ribuan ID ->
    // buang titik saja. Titik tunggal desimal betulan (10.5)
    // dipertahankan; titik ganda = ribuan, dibuang semua (1.234.567).
    // Multi-titik berujung 2 digit dibiarkan ke tryParse supaya tetap
    // throw seperti dulu.
    final frac = RegExp(r'\.(\d+)$').firstMatch(t)?.group(1) ?? '';
    final single = t.indexOf('.') == t.lastIndexOf('.');
    if (frac.isNotEmpty && RegExp(r'^0+$').hasMatch(frac)) {
      norm = frac.length == 3
          ? t.replaceAll('.', '')
          : t.substring(0, t.lastIndexOf('.'));
    } else if (single || RegExp(r'\.\d{2}$').hasMatch(t)) {
      norm = t;
    } else {
      norm = t.replaceAll('.', '');
    }
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
  if (c == 61 || c == 43 || c == 45 || c == 64) return "'${s.trimLeft()}";
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
  return _unquote(cells[idx]);
}

/// Buang kutip pembungkus + trim (cermin _splitCsvLine untuk satu sel).
String _unquote(String c) {
  var s = c.trim();
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    s = s.substring(1, s.length - 1).replaceAll('""', '"').trim();
  }
  return s;
}

bool _isFormula(String s) {
  final t = s.trimLeft();
  if (t.isEmpty) return false;
  final c = t.codeUnitAt(0);
  return c == 61 || c == 43 || c == 45 || c == 64;
}

/// Indeks kolom per field dari header lowercase+trim. Alias ID/EN tunggal
/// dipakai parseCsvPreview dan parseHeaderNames supaya tak divergen.
Map<String, int> _headerIndexes(List<String> header) {
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
      case 'dompet_id':
        iDompet = i;
      case 'ke_dompet':
      case 'to_wallet':
      case 'ke dompet':
      case 'ke_dompet_id':
        iKeDompet = i;
      case 'kategori':
      case 'category':
        iKategori = i;
      case 'catatan':
      case 'note':
        iCatatan = i;
    }
  }
  return {
    'date': iTanggal,
    'amount': iNominal,
    'type': iJenis,
    'wallet': iDompet,
    'towallet': iKeDompet,
    'cat': iKategori,
    'note': iCatatan,
  };
}

/// Petakan baris header ke field impor (nama header asli atau null).
/// Dipakai layar pratinjau; alias SAMA dengan parseCsvPreview.
Map<String, String?> parseHeaderNames(String headerLine, String delim) {
  final cells = _splitCsvLine(headerLine, delim);
  final lowered = cells.map((h) => h.trim().toLowerCase()).toList();
  final idx = _headerIndexes(lowered);
  String? nameAt(String field) {
    final i = idx[field] ?? -1;
    if (i < 0 || i >= cells.length) return null;
    return _unquote(cells[i]);
  }

  return {
    'date': nameAt('date'),
    'amount': nameAt('amount'),
    'type': nameAt('type'),
    'wallet': nameAt('wallet'),
    'towallet': nameAt('towallet'),
    'cat': nameAt('cat'),
    'note': nameAt('note'),
  };
}

/// Aturan tujuan transfer CSV: non-transfer selalu null; transfer pakai
/// id cocok dulu, else fallback bila beda dari asal, else null.
String? resolveToWalletId({
  required String type,
  required String? matchedToId,
  required String? srcId,
  required String? fallbackId,
}) {
  if (type != 'transfer') return null;
  if (matchedToId != null) return matchedToId;
  if (fallbackId != null && fallbackId != srcId) return fallbackId;
  return null;
}

/// Parse teks CSV jadi preview baris + error per baris. Header
/// case-insensitive (lowercase+trim) dengan alias ID/EN; wajib ada
/// kolom tanggal + nominal + jenis. Baris kosong dilewati diam-diam;
/// sel formula dinetralkan untuk field teks, tapi nominal formula
/// = error baris. Tak pernah throw untuk error data.
CsvImportPreview parseCsvPreview(String text) {
  // Batas jujur: teks > 5 MB ditolak mentah-mentah (paste raksasa = hang/OOM).
  if (text.length > 5 * 1024 * 1024) {
    return const CsvImportPreview([], [
      CsvImportError(0, 'file terlalu besar (maks 5 MB)'),
    ]);
  }
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
  final idx = _headerIndexes(header);
  final iTanggal = idx['date']!;
  final iNominal = idx['amount']!;
  final iJenis = idx['type']!;
  final iDompet = idx['wallet']!;
  final iKeDompet = idx['towallet']!;
  final iKategori = idx['cat']!;
  final iCatatan = idx['note']!;
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
    // Cap jujur: hanya 10.000 baris pertama diproses.
    if (rows.length >= 10000) {
      errors.add(const CsvImportError(
          0, 'melebihi 10.000 baris: hanya 10.000 baris pertama diproses'));
      break;
    }
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
