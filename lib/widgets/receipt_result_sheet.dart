import 'package:flutter/material.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';

// Replika struk thermal: urutan baris = urutan baris struk fisik,
// font monospace sistem, tanpa kartu. Baris dihitung mirrorReceipt
// (parseReceipt lama tetap untuk prefill, tak tersentuh).
// Dipakai setelah scan sukses (prefill form tetap jalan seperti biasa).
class ReceiptResultSheet extends StatelessWidget {
  final ReceiptData data;
  final List<MirrorLine> mirror;
  final VoidCallback onShowRaw;

  const ReceiptResultSheet({
    super.key,
    required this.data,
    required this.mirror,
    required this.onShowRaw,
  });

  String _idr(double v) =>
      amt(CurrencyService.toIdr(CurrencyService.convert(v)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warn = !data.confident;
    final firstItem = mirror.indexWhere((e) => e.amount != null && !e.bold);
    final firstTotal = mirror.indexWhere((e) => e.bold && e.amount != null);
    final items =
        mirror.where((e) => e.amount != null && !e.bold).toList();
    final subtotal =
        items.where((e) => e.amount! > 0).fold(0.0, (s, e) => s + e.amount!);
    final potongan = items
            .where((e) => e.amount! < 0)
            .fold(0.0, (s, e) => s - e.amount!) +
        (data.voucher ?? 0);
    final total = data.amount ?? (subtotal - potongan);
    final showSummary = items.isNotEmpty || data.amount != null;
    return SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SsrSpace.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < mirror.length; i++) ...[
                    if (i == firstItem || i == firstTotal)
                      const _DashedLine(),
                    _MirrorRow(
                      line: mirror[i],
                      money: _idr,
                    ),
                  ],
                  if (warn) ...[
                    const SizedBox(height: 4),
                    Text(
                      tr('rcp_check'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (showSummary) ...[
                    const SizedBox(height: SsrSpace.sm),
                    _SummaryBox(
                      subtotal: subtotal,
                      potongan: potongan,
                      total: total,
                      money: _idr,
                    ),
                  ],
                  const SizedBox(height: SsrSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(tr('rcp_raw_close')),
                        ),
                      ),
                      const SizedBox(width: SsrSpace.sm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onShowRaw,
                          child: Text(tr('rcp_raw_title')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}

/// Satu baris replika: polos tengah, atau nama (wrap penuh) + nominal
/// monospace tabular rata kanan.
class _MirrorRow extends StatelessWidget {
  final MirrorLine line;
  final String Function(double) money;

  const _MirrorRow({required this.line, required this.money});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (line.amount == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          line.text,
          textAlign: line.centered ? TextAlign.center : TextAlign.left,
          style: line.bold
              ? base?.copyWith(fontWeight: FontWeight.w700, fontSize: 16)
              : base,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nama produk wrap penuh (tak dipotong) + nominal rata kanan
          // sejajar tabular. Tanpa dot leader: rusak bila nama 2 baris.
          Expanded(
            child: Text(
              line.text,
              style: line.bold
                  ? base?.copyWith(fontWeight: FontWeight.w700)
                  : base,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            money(line.amount!),
            textAlign: TextAlign.right,
            softWrap: false,
            style: (line.bold
                    ? base?.copyWith(fontWeight: FontWeight.w700)
                    : base)
                ?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ringkasan M3: subtotal item + potongan (diskon/voucher/void) + total.
/// Angka tabular rata kanan; total tegas warna primer.
class _SummaryBox extends StatelessWidget {
  final double subtotal;
  final double potongan;
  final double total;
  final String Function(double) money;

  const _SummaryBox({
    required this.subtotal,
    required this.potongan,
    required this.total,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final num = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SsrSpace.md,
        vertical: SsrSpace.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _sumRow(context, tr('rcp_subtotal'), money(subtotal), num),
          if (potongan > 0) _sumRow(context, tr('rcp_discount'), money(potongan), num),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('rcp_total'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                money(total),
                textAlign: TextAlign.right,
                softWrap: false,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sumRow(
    BuildContext context,
    String label,
    String value,
    TextStyle? num,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          Text(value, textAlign: TextAlign.right, softWrap: false, style: num),
        ],
      ),
    );
  }
}

/// Garis putus-putus ala struk (deterministik, tanpa font khusus).
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : 200.0;
        final n = (w ~/ 9).clamp(4, 120);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < n; i++)
                Container(
                  width: 6,
                  height: 1.2,
                  margin: const EdgeInsets.only(right: 3),
                  color: color,
                ),
            ],
          ),
        );
      },
    );
  }
}
