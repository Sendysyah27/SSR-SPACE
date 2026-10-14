import 'package:flutter/material.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/tx_wallet_check.dart';
import 'package:ssr_space/services/space_logic.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:ssr_space/theme/category_emoji.dart';

class TxRow extends StatelessWidget {
  final SaasTransaction tx;
  final VoidCallback? onTap;
  final bool selected;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const TxRow({super.key, required this.tx, this.onTap, this.selected = false, this.onDelete, this.onEdit});

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

  List<Widget> _chips(String myId) {
    final by = tx.createdBy;
    final r =
        (by == null || by.isEmpty) ? null : actorLabel(by, myId);
    final byLabel = r == null
        ? null
        : (r.$2 ? tr('sp_by_you') : tr('sp_by_member').replaceFirst('{s}', r.$1));
    // Show max 3 chips: auto, wallet, category (creator shown only if others present)
    final chips = <Widget>[];
    // ignore: curly_braces_in_flow_control_structures
    if (tx.sourcePackage != null) chips.add(
      StatusChip(label: tr('tx_auto'), tone: StatusTone.accent, icon: AppIcons.autoBadge, isSmall: true),
    );
    // ignore: curly_braces_in_flow_control_structures
    if (hasNoWallet(tx)) chips.add(
      StatusChip(label: tr('tx_nowallet'), tone: StatusTone.danger),
    );
    // ignore: curly_braces_in_flow_control_structures
    if (tx.category != null && tx.category!.isNotEmpty) chips.add(
      StatusChip(label: "$categoryEmoji(tx.category!) ${tx.category!}", tone: StatusTone.neutral),
    );
    // ignore: curly_braces_in_flow_control_structures
    if (byLabel != null && chips.length >= 2) chips.add(
      StatusChip(label: byLabel, tone: r!.$2 ? StatusTone.accent : StatusTone.neutral),
    );
    return chips;
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
    final myId = SupabaseConfig.client.auth.currentUser?.id ?? '';
    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => _showDeleteConfirm(context),
      background: _buildSwipeLeft(context, scheme),
      secondaryBackground: _buildSwipeRight(context, scheme),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title(theme, amountColor),
                    const SizedBox(height: 6),
                    Wrap(spacing: 4, runSpacing: 2, children: _chips(myId)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                    ],
                    if (tx.note != null && tx.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => showNoteDialog(context, tx.note!),
                        child: Text(tx.note!, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
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

  Widget _buildSwipeLeft(BuildContext context, ColorScheme scheme) {
    return Container(
      color: scheme.error,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Text('Hapus', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildSwipeRight(BuildContext context, ColorScheme scheme) {
    return Container(
      color: scheme.primary,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Text('Edit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('tx_del_title')),
        content: Text(tr('tx_del_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
          TextButton(onPressed: () => onDelete?.call(), child: Text(tr('tx_delete'))),
        ],
      ),
    );
  }
}

/// Tampilkan dialog baca catatan transaksi (teks penuh).
void showNoteDialog(BuildContext context, String note) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('tx_f_note')),
      content: SingleChildScrollView(child: Text(note)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('close'))),
      ],
    ),
  );
}
