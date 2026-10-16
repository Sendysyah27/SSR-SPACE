import 'package:flutter/material.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/premium/glass_sheet.dart';
import 'package:ssr_space/widgets/premium/premium_button.dart';
import 'package:ssr_space/widgets/drib_card.dart';
import 'package:ssr_space/services/receipt_scan_parse.dart';

/// Detail transaksi read-only dari ketuk notif tersimpan.
/// Kembalikan true bila user pilih Lihat di Transaksi.
Future<bool?> showTxDetailSheet(
  BuildContext context,
  SaasTransaction tx,
  String orgId,
) {
  return showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        GlassSheetScaffold(child: _TxDetailSheet(tx: tx, orgId: orgId)),
  );
}

class _TxDetailSheet extends StatelessWidget {
  final SaasTransaction tx;
  final String orgId;

  const _TxDetailSheet({required this.tx, required this.orgId});

  Future<Map<String, String>> _names() async {
    try {
      final ws = await WalletService().list(orgId);
      return {for (final w in ws) w.id: w.name};
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final dir = tx.type == 'in'
        ? tr('tx_in')
        : tx.type == 'transfer'
            ? tr('tx_transfer')
            : tr('tx_out');
    return FutureBuilder<Map<String, String>>(
        future: _names(),
        builder: (context, snap) {
          final names = snap.data ?? {};
          final wallet = names[tx.walletId] ?? '…';
          final toWallet = tx.toWalletId == null
              ? null
              : (names[tx.toWalletId] ?? '…');
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              SsrSpace.lg,
              SsrSpace.sm,
              SsrSpace.lg,
              SsrSpace.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('td_title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: SsrSpace.sm),
                DribCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '$dir ${amt(tx.amount)}',
                        style: DribTokens.bigNumber(
                            size: 26, color: DribTokens.navy),
                      ),
                      const SizedBox(height: SsrSpace.sm),
                      _row(context, tr('td_wallet'), wallet),
                      if (toWallet != null)
                        _row(context, tr('td_towallet'), toWallet),
                      _row(
                        context,
                        tr('tx_f_cat'),
                        (tx.category?.isEmpty ?? true)
                            ? '-'
                            : tx.category!,
                      ),
                      _receiptNoteRow(context, tx),
                      _row(
                        context,
                        tr('tx_f_date'),
                        txWhenLabel(tx.date, tx.createdAt),
                      ),
                      if (tx.code != null && tx.code!.isNotEmpty)
                        _row(context, 'TX', tx.code!),
                    ],
                  ),
                ),
                const SizedBox(height: SsrSpace.md),
                PremiumButton(
                  label: tr('td_view'),
                  onPressed: () => Navigator.pop(context, true),
                  gradient: const LinearGradient(
                    colors: [
                      DribTokens.primary,
                      DribTokens.primary
                    ],
                  ),
                  foreground: DribTokens.navy,
                ),
                const SizedBox(height: SsrSpace.sm),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(tr('td_close')),
                ),
              ],
            ),
          );
        },
      );
  }

  Widget _receiptNoteRow(BuildContext context, SaasTransaction tx) {
    final theme = Theme.of(context);
    final note = (tx.note?.isEmpty ?? true) ? '-' : tx.note!;
    final receipt = isReceiptDetailNote(tx.note);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(tr('tx_f_note'), style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              note,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: receipt ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
