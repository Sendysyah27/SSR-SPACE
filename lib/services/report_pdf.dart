import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/utils/money.dart';
import 'package:ssr_space/utils/strings.dart';

const _ink = PdfColor.fromInt(0xFF1C1B1A);
const _accent = PdfColor.fromInt(0xFF0E4B44);
const _emeraldDeep = PdfColor.fromInt(0xFF0A332E);
const _accentSoft = PdfColor.fromInt(0xFFE6F3F1);
const _goldSoft = PdfColor.fromInt(0xFFEDE2C1);
const _danger = PdfColor.fromInt(0xFFB3261E);
const _dangerSoft = PdfColor.fromInt(0xFFF9E8E6);
const _paper = PdfColor.fromInt(0xFFF3F2EE);
const _muted = PdfColor.fromInt(0xFF5F5E5B);

Future<pw.Font?> _bundledFont() async {
  try {
    final data = await rootBundle.load(
      'assets/fonts/PlusJakartaSans-VariableFont_wght.ttf',
    );
    return pw.Font.ttf(data);
  } catch (_) {
    return null;
  }
}

String _typeLabel(String type) {
  if (type == 'in') return tr('tx_in');
  if (type == 'out') return tr('tx_out');
  return tr('tx_transfer');
}

PdfColor _typeColor(String type) {
  if (type == 'in') return _accent;
  if (type == 'out') return _danger;
  return _ink;
}

/// Laporan bulanan terstruktur: kop + ringkasan + tabel + rekap kategori.
///
/// [walletLabel]/[typeLabel] null = semua (tampil "Semua" di baris filter).
/// [walletNames] peta id dompet ke nama untuk kolom Dompet tabel.
Future<Uint8List> buildReportPdf({
  required String orgName,
  required String monthLabel,
  required List<SaasTransaction> items,
  String? walletLabel,
  String? typeLabel,
  Map<String, String> walletNames = const {},
}) async {
  final base = await _bundledFont();
  final theme = base == null
      ? null
      : pw.ThemeData.withFont(base: base, bold: base);
  final doc = pw.Document(theme: theme);
  final now = DateTime.now();
  final made = '${now.day}-${now.month}-${now.year}';

  final totalIn = items
      .where((t) => t.type == 'in')
      .fold<double>(0, (s, t) => s + t.amount);
  final totalOut = items
      .where((t) => t.type == 'out')
      .fold<double>(0, (s, t) => s + t.amount);
  final byCat = <String, double>{};
  for (final t in items.where((t) => t.type == 'out')) {
    final c = (t.category == null || t.category!.trim().isEmpty)
        ? tr('cat_other')
        : t.category!.trim();
    byCat[c] = (byCat[c] ?? 0) + t.amount;
  }
  final topCats = byCat.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(height: 6, color: _accent),
          pw.SizedBox(height: 12),
          pw.Text(
            'SSR SPACE',
            style: const pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 2,
              color: _accent,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            tr('pdf_title'),
            style: const pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.Text(
            '$monthLabel  •  $orgName',
            style: const pw.TextStyle(fontSize: 11, color: _muted),
          ),
          pw.Text(
            tr('pdf_filter')
                .replaceFirst('{w}', walletLabel ?? tr('pdf_all'))
                .replaceFirst('{t}', typeLabel ?? tr('pdf_all')),
            style: const pw.TextStyle(fontSize: 10, color: _muted),
          ),
          pw.SizedBox(height: 12),
        ],
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            tr('pdf_made').replaceFirst('{d}', made),
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
          pw.Text(
            tr('pdf_page')
                .replaceFirst('{p}', '${ctx.pageNumber}')
                .replaceFirst('{t}', '${ctx.pagesCount}'),
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
      build: (_) => [
        _summary(totalIn, totalOut),
        pw.SizedBox(height: 16),
        pw.Text(
          tr('pdf_txs').replaceFirst('{n}', '${items.length}'),
          style: const pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 6),
        if (items.isEmpty)
          pw.Text(
            tr('pdf_empty'),
            style: const pw.TextStyle(fontSize: 11, color: _muted),
          )
        else
          _table(items, walletNames),
        if (topCats.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            tr('pdf_cats'),
            style: const pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 6),
          ...topCats
              .take(8)
              .map((e) => _catRow(e.key, e.value, topCats.first.value)),
        ],
      ],
    ),
  );
  return doc.save();
}

pw.Widget _summary(double totalIn, double totalOut) {
  pw.Widget box(String label, String value, PdfColor tint, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: tint,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 10, color: _muted),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  final net = totalIn - totalOut;
  final surplus = net >= 0;
  return pw.Row(
    children: [
      box(tr('tx_in'), rp(totalIn), _accentSoft, _accent),
      pw.SizedBox(width: 8),
      box(tr('tx_out'), rp(totalOut), _dangerSoft, _danger),
      pw.SizedBox(width: 8),
      // Aksen gold hanya untuk selisih surplus (aturan DESIGN.md).
      box(tr('pdf_diff'), rp(net), surplus ? _goldSoft : _dangerSoft,
          surplus ? _accent : _danger),
    ],
  );
}

pw.Widget _table(List<SaasTransaction> items, Map<String, String> names) {
  pw.Widget cell(
    String text, {
    PdfColor color = _ink,
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String walletOf(SaasTransaction t) {
    final from = names[t.walletId] ?? '';
    final to = names[t.toWalletId] ?? '';
    if (t.type == 'transfer' && to.isNotEmpty && to != from) {
      return from.isEmpty ? to : '$from → $to';
    }
    return from.isEmpty ? '-' : from;
  }

  // Kepala emeraldDeep + baris zebra + garis hairline ledger.
  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: _emeraldDeep),
      children: [
        cell(tr('pdf_h_date'), color: PdfColors.white, bold: true),
        cell(tr('pdf_h_type'), color: PdfColors.white, bold: true),
        cell(tr('pdf_h_wallet'), color: PdfColors.white, bold: true),
        cell(tr('bt_cat'), color: PdfColors.white, bold: true),
        cell(
          tr('pdf_h_amount'),
          color: PdfColors.white,
          bold: true,
          align: pw.TextAlign.right,
        ),
        cell(tr('pdf_h_note'), color: PdfColors.white, bold: true),
      ],
    ),
    for (var i = 0; i < items.length; i++)
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: i.isEven ? PdfColors.white : _paper,
        ),
        children: [
          cell(items[i].date ?? '-'),
          cell(
            _typeLabel(items[i].type),
            color: _typeColor(items[i].type),
            bold: true,
          ),
          cell(walletOf(items[i])),
          cell(items[i].category ?? tr('cat_other')),
          cell(
            rp(items[i].amount),
            color: _typeColor(items[i].type),
            bold: true,
            align: pw.TextAlign.right,
          ),
          cell(items[i].note ?? '-'),
        ],
      ),
  ];
  return pw.Table(
    columnWidths: {
      0: const pw.FixedColumnWidth(52),
      1: const pw.FixedColumnWidth(48),
      2: const pw.FlexColumnWidth(2),
      3: const pw.FlexColumnWidth(2),
      4: const pw.FixedColumnWidth(74),
      5: const pw.FlexColumnWidth(2),
    },
    // ignore: prefer_const_constructors (TableBorder.all bukan const ctor)
    border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE0DED8), width: 0.5),
    children: rows,
  );
}

pw.Widget _catRow(String name, double amount, double maxAmount) {
  final frac = maxAmount <= 0 ? 0.0 : (amount / maxAmount).clamp(0.0, 1.0);
  // Flex minimal 1 agar tak ada segmen nol di Row pdf.
  final a = (frac * 1000).round().clamp(1, 1000);
  final b = 1001 - a;
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 8,
              height: 8,
              decoration: const pw.BoxDecoration(
                color: _accent,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Text(name, style: const pw.TextStyle(fontSize: 11)),
            ),
            pw.Text(
              rp(amount),
              style: const pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          children: [
            pw.SizedBox(width: 16),
            pw.Expanded(
              flex: a,
              child: pw.Container(height: 3, color: _accent),
            ),
            pw.Expanded(
              flex: b,
              child: pw.Container(height: 3, color: _paper),
            ),
          ],
        ),
      ],
    ),
  );
}
