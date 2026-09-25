import 'package:flutter/material.dart';
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/saas/category_icons.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/widgets/status_chip.dart';

class TxRow extends StatelessWidget {
  final SaasTransaction tx;
  final VoidCallback? onTap;
  final bool selected;

  const TxRow({super.key, required this.tx, this.onTap, this.selected = false});

  String get _kindLabel {
    switch (tx.type) {
      case 'in':
        return 'Masuk';
      case 'transfer':
        return 'Transfer';
      default:
        return 'Keluar';
    }
  }

  Color get _amountColor {
    if (tx.type == 'in') return SsrColors.accent;
    if (tx.type == 'out') return SsrColors.danger;
    return SsrColors.ink;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auto = tx.sourcePackage != null;
    final chips = <Widget>[
      StatusChip(label: tx.code ?? 'Tanpa kode', tone: StatusTone.neutral),
      if (auto)
        const StatusChip(
          label: 'Otomatis',
          tone: StatusTone.accent,
          icon: Icons.bolt,
        ),
      if (tx.category != null && tx.category!.isNotEmpty)
        StatusChip(label: tx.category!, tone: StatusTone.neutral),
    ];

    return Material(
      color: selected ? SsrColors.accentSoft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: SsrColors.accentSoft,
                  borderRadius: BorderRadius.circular(SsrRadius.tile),
                ),
                child: Icon(
                  iconForCategory(tx.category),
                  color: SsrColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_kindLabel: ${rp(tx.amount)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _amountColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: chips),
                    if (tx.note != null && tx.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tx.note!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
