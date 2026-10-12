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
    return SafeArea(
      child: SelectionArea(
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
      ),
    );
  }
}

/// Satu baris replika: polos tengah, atau nama .... nominal monospace.
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
        children: [
          Flexible(
            child: Text(
              line.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: line.bold
                  ? base?.copyWith(fontWeight: FontWeight.w700)
                  : base,
            ),
          ),
          const Expanded(child: _DotLeader()),
          Text(
            money(line.amount!),
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
/// Deret titik pengisi lebar sisa (dot leader struk).
class _DotLeader extends StatelessWidget {
  const _DotLeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : 200.0;
        final n = (w ~/ 7).clamp(2, 80);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            List.filled(n, '·').join(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontFamily: 'monospace',
            ),
          ),
        );
      },
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
