import 'package:flutter/material.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/receipt_parse.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';

// Hasil OCR ala layout struk: merchant + item dot-leader + total tebal.
// Dipakai setelah scan sukses (prefill form tetap jalan seperti biasa).
class ReceiptResultSheet extends StatelessWidget {
  final ReceiptData data;
  final VoidCallback onShowRaw;

  const ReceiptResultSheet({
    super.key,
    required this.data,
    required this.onShowRaw,
  });

  String _idr(double v) =>
      amt(CurrencyService.toIdr(CurrencyService.convert(v)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warn = !data.confident;
    final total = data.amount ?? 0;
    final date = data.date;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              data.merchant ?? tr('rcp_scan'),
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SsrSpace.sm),
            const _DashedLine(),
            for (final raw in data.items) _ItemRow(raw: raw, money: _idr),
            const _DashedLine(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('rcp_total'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _idr(total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: warn ? scheme.error : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (warn) ...[
              const SizedBox(height: 4),
              Text(
                tr('rcp_check'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
            if (date != null) ...[
              const SizedBox(height: 4),
              Text(
                '${date.day.toString().padLeft(2, '0')}-'
                '${date.month.toString().padLeft(2, '0')}-'
                '${date.year}',
                style: theme.textTheme.bodySmall,
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
    );
  }
}

/// Satu baris produk: nama .... nominal (dot leader).
class _ItemRow extends StatelessWidget {
  final String raw;
  final String Function(double) money;

  const _ItemRow({required this.raw, required this.money});

  @override
  Widget build(BuildContext context) {
    final p = splitReceiptItem(raw);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const _DotLeader(),
          Text(
            money(p.amount),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
        final n = (c.maxWidth ~/ 7).clamp(2, 80);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            List.filled(n, '·').join(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
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
        final n = (c.maxWidth ~/ 9).clamp(4, 120);
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
