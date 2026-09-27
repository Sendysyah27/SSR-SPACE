import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/tx_wallet_check.dart';
import 'package:ssr_space/services/category_icons.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/status_chip.dart';

class TxRow extends StatelessWidget {
  final SaasTransaction tx;
  final VoidCallback? onTap;
  final bool selected;

  const TxRow({super.key, required this.tx, this.onTap, this.selected = false});

  String get _kindLabel {
    switch (tx.type) {
      case 'in':
        return tr('tx_in');
      case 'transfer':
        return tr('tx_transfer');
      default:
        return tr('tx_out');
    }
  }

  bool get _isOut => tx.type == 'out';

  Color _amountColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (tx.type == 'in') return scheme.primary;
    if (tx.type == 'out') return scheme.error;
    return scheme.onSurface;
  }

  IconData get _directionIcon {
    if (tx.type == 'in') return AppIcons.txIn;
    if (tx.type == 'out') return AppIcons.txOut;
    return AppIcons.transfer;
  }

  String get _signedAmount {
    final nominal = amt(tx.amount);
    if (tx.type == 'in') return '+ $nominal';
    if (tx.type == 'out') return '− $nominal';
    return nominal;
  }

  String get _subtitle {
    final when = txWhenLabel(tx.date, tx.createdAt);
    final code = tx.code;
    if (code == null || code.isEmpty) return when;
    if (when.isEmpty) return code;
    return '$when · $code';
  }

  List<Widget> _chips() {
    return [
      if (tx.sourcePackage != null)
        StatusChip(label: tr('tx_auto'), tone: StatusTone.accent, icon: AppIcons.autoBadge),
      if (hasNoWallet(tx))
        StatusChip(label: tr('tx_nowallet'), tone: StatusTone.danger),
      if (tx.category != null && tx.category!.isNotEmpty)
        StatusChip(label: tx.category!, tone: StatusTone.neutral),
    ];
  }

  Widget _title(ThemeData theme, Color amountColor) {
    return Row(
      children: [
        DuoIcon(_directionIcon, size: 16, color: amountColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$_kindLabel: ', style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600)),
                TextSpan(text: _signedAmount, style: TextStyle(fontFamily: SsrFonts.numeric, fontSize: 15, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()], color: amountColor)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountColor = _amountColor(context);
    final subtitle = _subtitle;
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TxBadge(isOut: _isOut, category: tx.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title(theme, amountColor),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: _chips()),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                    ],
                    if (tx.note != null && tx.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(tx.note!, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
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

class _TxBadge extends StatelessWidget {
  final bool isOut;
  final String? category;

  const _TxBadge({required this.isOut, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isOut ? AppColors.rust.withValues(alpha: 0.12) : AppColors.goldSoft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Center(
        child: SvgPicture.asset(
          svgForCategory(category),
          width: 19,
          colorFilter: ColorFilter.mode(isOut ? AppColors.rust : const Color(0xFF7A5E14), BlendMode.srcIn),
        ),
      ),
    );
  }
}
