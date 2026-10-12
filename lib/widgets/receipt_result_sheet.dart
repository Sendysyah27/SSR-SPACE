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
    final items = data.lineItems.isNotEmpty
        ? [
            for (final li in data.lineItems)
              (name: li.qty > 1 ? '${li.name} x${li.qty}' : li.name,
               amount: li.price),
          ]
        : [for (final raw in data.items) splitReceiptItem(raw)];
    final dateStr = date == null
        ? null
        : '${date.day.toString().padLeft(2, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.year}'
            '${data.time == null ? '' : ' ${data.time}'}';
    return SafeArea(
      child: SelectionArea(
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
            if (data.address != null || data.phone != null) ...[
              const SizedBox(height: 4),
              if (data.address != null)
                Text(
                  data.address!,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              if (data.phone != null)
                Text(
                  data.phone!,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
            ],
            const SizedBox(height: SsrSpace.sm),
            const _DashedLine(),
            _MetaRow(
              label: tr('rcp_no'),
              value: data.receiptNo,
            ),
            _MetaRow(label: tr('tx_f_date'), value: dateStr),
            _MetaRow(label: tr('rcp_cashier'), value: data.cashier),
            if (items.isNotEmpty) ...[
              const SizedBox(height: SsrSpace.sm),
              Text(
                tr('rcp_items'),
                style: theme.textTheme.titleSmall,
              ),
              for (final p in items) _ItemRow(name: p.name, amount: p.amount, money: _idr),
            ],
            const _DashedLine(),
            if (data.voucher != null && data.voucher! > 0) ...[
              _MoneyRow(label: tr('rcp_subtotal'), value: total + data.voucher!),
              _MoneyRow(label: tr('rcp_discount'), value: -data.voucher!),
            ],
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
            _MetaRow(label: tr('rcp_pay'), value: data.payType),
            if (warn) ...[
              const SizedBox(height: 4),
              Text(
                tr('rcp_check'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
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
    );
  }
}

/// Baris meta kecil (label kiri, nilai kanan). Null = sembunyi.
class _MetaRow extends StatelessWidget {
  final String label;
  final String? value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            value!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris uang (subtotal/diskon): label kiri, nominal kanan tabular.
class _MoneyRow extends StatelessWidget {
  final String label;
  final double value;

  const _MoneyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            amt(CurrencyService.toIdr(CurrencyService.convert(value))),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu baris produk: nama .... nominal (dot leader).
class _ItemRow extends StatelessWidget {
  final String name;
  final double amount;
  final String Function(double) money;

  const _ItemRow({required this.name, required this.amount, required this.money});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const Expanded(child: _DotLeader()),
          Text(
            money(amount),
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
        final w = c.maxWidth.isFinite ? c.maxWidth : 200.0;
        final n = (w ~/ 7).clamp(2, 80);
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
