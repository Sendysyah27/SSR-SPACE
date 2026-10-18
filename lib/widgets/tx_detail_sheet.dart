import 'package:flutter/material.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/widgets/tx_input_sheet.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/services/transaction_service.dart';
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
                            size: 26,
                            color: Theme.of(context).colorScheme.onSurface),
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
/// Detail transaksi ala referensi (adaptasi konsep, tanpa brand):
/// header amount besar + lingkaran panah pastel + "IDR · Expense",
/// rows Title/Category/Wallet/Date/Time/Note (label kiri, nilai kanan),
/// tombol hapus (pink soft) + Edit (gelap).
///
/// Kembalikan true bila ada perubahan (edit tersimpan / dihapus) agar
/// pemanggil bisa muat ulang. Fungsi lama [showTxDetailSheet] (jalur
/// notif) tidak diubah.
Future<bool> showOlloTxDetailSheet(
  BuildContext context,
  SaasTransaction tx,
) async {
  var changed = false;
  var doEdit = false;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OlloTxDetailSheet(
      tx: tx,
      onChanged: () => changed = true,
      onEdit: () => doEdit = true,
    ),
  );
  if (doEdit && context.mounted) {
    final saved = await openTxInputSheet(context, editing: tx);
    return saved || changed;
  }
  return changed;
}

class _OlloTxDetailSheet extends StatefulWidget {
  final SaasTransaction tx;
  final VoidCallback onChanged;
  final VoidCallback onEdit;

  const _OlloTxDetailSheet({
    required this.tx,
    required this.onChanged,
    required this.onEdit,
  });

  @override
  State<_OlloTxDetailSheet> createState() => _OlloTxDetailSheetState();
}

class _OlloTxDetailSheetState extends State<_OlloTxDetailSheet> {
  bool _deleting = false;
  String? _err;
  Map<String, String> _walletNames = const {};

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty || !mounted) return;
      final ws = await WalletService().list(orgId);
      if (mounted) {
        setState(() => _walletNames = {for (final w in ws) w.id: w.name});
      }
    } catch (_) {}
  }

  SaasTransaction get tx => widget.tx;

  bool get isIncome => tx.type == 'in';
  bool get isTransfer => tx.type == 'transfer';

  Color _amountColor(ColorScheme scheme) {
    if (isIncome) return Colors.green.shade600;
    if (isTransfer) return scheme.onSurface;
    return Colors.red.shade600;
  }

  String _signedAmount() {
    final nominal = amt(tx.amount);
    if (isIncome) return '+$nominal';
    if (isTransfer) return nominal;
    return '-$nominal';
  }

  String _typeLabel() {
    if (isIncome) return tr('txd_idr_in');
    if (isTransfer) return tr('txd_idr_transfer');
    return tr('txd_idr_out');
  }

  /// Judul: segmen pertama catatan ("judul · catatan"), fallback kategori.
  String _title() {
    final note = tx.note?.trim() ?? '';
    if (note.isNotEmpty) {
      final first = note.split('·').first.trim();
      if (first.isNotEmpty) return first;
    }
    final cat = tx.category?.trim() ?? '';
    if (cat.isNotEmpty) return cat;
    return '-';
  }

  Future<void> _delete() async {
    if (_deleting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('tx_del_title')),
        content: Text(tr('tx_del_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('tx_delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _deleting = true;
      _err = null;
    });
    try {
      final orgId = await activeOrgId();
      if (orgId.isNotEmpty) {
        await TransactionService().delete(tx.id, orgId);
      }
      if (!mounted) return;
      widget.onChanged();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _err = e.toString();
      });
    }
  }

  Widget _row(ColorScheme scheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amountColor = _amountColor(scheme);
    final arrowIcon = isIncome ? AppIcons.txIn : AppIcons.txOut;
    final walletName = _walletNames[tx.walletId] ?? '…';
    final dateStr = dayLabel(tx.date);
    final timeStr = txTime(tx.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: DribTokens.cardOf(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DribTokens.sheetRadius),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: scheme.outlineVariant,
            ),
          ),
          const SizedBox(height: 16),
          // Lingkaran pastel panah arah
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: amountColor.withValues(alpha: 0.15),
            ),
            alignment: Alignment.center,
            child: DuoIcon(arrowIcon, size: 30, color: amountColor),
          ),
          const SizedBox(height: 12),
          // Amount besar
          Text(
            _signedAmount(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: amountColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _typeLabel(),
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _row(scheme, tr('txd_title'), _title()),
                  _row(
                    scheme,
                    tr('txd_category'),
                    (tx.category?.isEmpty ?? true) ? '-' : tx.category!,
                  ),
                  _row(scheme, tr('tx_f_wallet'), walletName),
                  _row(scheme, tr('tx_f_date'), dateStr.isEmpty ? '-' : dateStr),
                  _row(scheme, tr('txd_time'), timeStr.isEmpty ? '-' : timeStr),
                  _row(
                    scheme,
                    tr('tx_f_note'),
                    (tx.note?.isEmpty ?? true) ? '-' : tx.note!,
                  ),
                ],
              ),
            ),
          ),
          if (_err != null) ...[
            const SizedBox(height: 8),
            Text(
              _err!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              // Hapus: pink soft
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.pink.shade100,
                    foregroundColor: Colors.pink.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _deleting ? null : _delete,
                  child: _deleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          tr('tx_delete'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Edit: gelap
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.inverseSurface,
                    foregroundColor: scheme.onInverseSurface,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _deleting
                      ? null
                      : () {
                          widget.onEdit();
                          Navigator.of(context).pop();
                        },
                  child: Text(
                    tr('txd_edit'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
