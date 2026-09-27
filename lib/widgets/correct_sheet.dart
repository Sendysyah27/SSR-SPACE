import 'package:flutter/material.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/instant_correct.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/primary_button.dart';

/// Sheet koreksi instan: pilih kategori (chip global) + catatan + Simpan/Lewati.
/// Dibuka dari overlay 30 detik / ketuk notif service / resume dengan pending.
Future<void> showCorrectSheet(
  BuildContext context,
  SaasTransaction tx,
  String orgId,
) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CorrectSheet(tx: tx, orgId: orgId),
  );
  await InstantCorrect.clearPending();
}

class _CorrectSheet extends StatefulWidget {
  final SaasTransaction tx;
  final String orgId;

  const _CorrectSheet({required this.tx, required this.orgId});

  @override
  State<_CorrectSheet> createState() => _CorrectSheetState();
}

class _CorrectSheetState extends State<_CorrectSheet> {
  String? sel;
  final noteC = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final cur = widget.tx.category?.trim() ?? '';
    sel = cur.isNotEmpty && appCategories.value.contains(cur) ? cur : null;
    noteC.text = widget.tx.note ?? '';
  }

  @override
  void dispose() {
    noteC.dispose();
    super.dispose();
  }

  String get _dirLabel => widget.tx.type == 'in' ? tr('tx_in') : tr('tx_out');

  Future<void> _save({required bool keepNote}) async {
    if (!keepNote && sel == null && noteC.text.trim().isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => saving = true);
    try {
      final t = widget.tx;
      final noteText = noteC.text.trim();
      await TransactionService().update(
        id: t.id,
        orgId: widget.orgId,
        type: t.type,
        amount: t.amount,
        walletId: t.walletId,
        toWalletId: t.toWalletId,
        date: t.date,
        category: sel ?? t.category,
        note: keepNote ? t.note : (noteText.isEmpty ? null : noteText),
      );
      try {
        if (t.walletId != null) await noteWalletUsed(t.walletId!);
        if (t.toWalletId != null) await noteWalletUsed(t.toWalletId!);
      } catch (_) {}
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('ic_saved'))));
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('conn_error'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: SsrSpace.lg,
          right: SsrSpace.lg,
          top: SsrSpace.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + SsrSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('ic_sheet_t'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: SsrSpace.xs),
            Text(
              '$_dirLabel: ${amt(widget.tx.amount)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SsrColors.secondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: SsrSpace.md),
            _CatPicker(
              selected: sel,
              onPick: (c) => setState(() => sel = c == sel ? null : c),
            ),
            const SizedBox(height: SsrSpace.md),
            TextField(
              controller: noteC,
              decoration: InputDecoration(hintText: tr('ic_note_hint')),
              maxLines: 2,
            ),
            const SizedBox(height: SsrSpace.md),
            Row(
              children: [
                TextButton(
                  onPressed: saving ? null : () => _save(keepNote: true),
                  child: Text(tr('ic_skip')),
                ),
                const SizedBox(width: SsrSpace.sm),
                Expanded(
                  child: PrimaryButton(
                    label: tr('save'),
                    loading: saving,
                    onPressed: () => _save(keepNote: false),
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

/// Chip kategori global; ikut berubah bila daftar di-customize.
class _CatPicker extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onPick;

  const _CatPicker({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: appCategories,
      builder: (_, cats, __) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in cats)
            ChoiceChip(
              label: Text(c),
              selected: selected == c,
              onSelected: (_) => onPick(c),
            ),
        ],
      ),
    );
  }
}
