import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/services/tx_validation.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/models/wallet_balance.dart';
import 'package:ssr_space/widgets/month_picker.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/success_lottie.dart';
import 'package:ssr_space/widgets/tx_row.dart';
import 'package:ssr_space/widgets/category_chips.dart';
import 'package:ssr_space/widgets/tx_type_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String txHistoryTitle(String m) {
  final label = localeCode.value == 'en'
      ? monthLabel(m)
      : monthLabel(m).toLowerCase();
  return tr('tx_history').replaceFirst('{m}', label);
}

class TransactionsScreen extends StatefulWidget {
  final String? initialMonth;
  const TransactionsScreen({super.key, this.initialMonth});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late String month;
  List<SaasTransaction> items = [];
  List<Wallet> wallets = [];
  List<WalletBalance> balances = [];
  SaasTransaction? editing;
  DateTime? editDate;
  final formKey = GlobalKey();
  bool noOrg = false;
  bool loading = true;
  bool saving = false;
  String? err;
  String? formErr;
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  final catC = TextEditingController();
  String type = 'out';
  String? walletId;
  String? toWalletId;

  @override
  void initState() {
    super.initState();
    month = widget.initialMonth ?? currentMonth();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await activeOrgId();
      if (orgId.isEmpty) {
        setState(() {
          noOrg = true;
          loading = false;
        });
        return;
      }
      final w = await WalletService().list(orgId);
      List<WalletBalance> bals = [];
      try {
        bals = await WalletService().balances(orgId);
      } catch (_) {
        bals = [];
      }
      final t = await TransactionService().listMonth(orgId, month);
      if (!mounted) return;
      setState(() {
        noOrg = false;
        wallets = w;
        balances = bals;
        items = t;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = tr('tx_err_load');
      });
    }
  }

  double? _balanceOf(String? id) {
    if (id == null) return null;
    for (final b in balances) {
      if (b.walletId == id) return b.balance;
    }
    return null;
  }

  void _startEdit(SaasTransaction t) {
    setState(() {
      editing = t;
      type = t.type;
      amountC.text = t.amount.toStringAsFixed(0);
      catC.text = t.category ?? '';
      noteC.text = t.note ?? '';
      walletId = t.walletId;
      toWalletId = t.toWalletId;
      editDate = t.date == null ? null : DateTime.tryParse(t.date!);
      formErr = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = formKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: SsrMotion.base,
          curve: SsrMotion.curve,
        );
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      editing = null;
      editDate = null;
      type = 'out';
      amountC.clear();
      noteC.clear();
      catC.clear();
      walletId = null;
      toWalletId = null;
      formErr = null;
    });
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final typed = double.tryParse(amountC.text);
    if (typed == null) {
      setState(() => formErr = tr('tx_err_amount'));
      return;
    }
    final nominal = CurrencyService.toIdr(typed);
    final v = validateTxInput(
      amount: nominal,
      walletId: walletId,
      type: type,
      toWalletId: toWalletId,
    );
    if (v != null) {
      setState(() => formErr = v);
      return;
    }
    setState(() {
      saving = true;
      formErr = null;
    });
    try {
      final orgId = await activeOrgId();
      final cat = catC.text.trim().isEmpty ? null : catC.text.trim();
      final note = noteC.text.trim();
      final svc = TransactionService();
      if (editing != null) {
        await svc.update(
          id: editing!.id,
          orgId: orgId,
          type: type,
          amount: nominal,
          walletId: walletId,
          toWalletId: type == 'transfer' ? toWalletId : null,
          category: cat,
          note: note.isEmpty ? null : note,
          date: editDate == null ? editing!.date : _ymd(editDate!),
        );
        if (!mounted) return;
        _cancelEdit();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('tx_updated'))));
        unawaited(showSuccessFlash(context));
      } else {
        await svc.add(
          orgId: orgId,
          type: type,
          amount: nominal,
          walletId: walletId,
          toWalletId: type == 'transfer' ? toWalletId : null,
          category: cat,
          note: note,
        );
        if (!mounted) return;
        amountC.clear();
        noteC.clear();
        catC.clear();
        setState(() {
          walletId = null;
          toWalletId = null;
        });
        unawaited(showSuccessFlash(context));
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      debugPrint('save tx: $e');
      setState(() => formErr = _txError(e, tr('tx_act_save')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _txError(Object e, String action) {
    if (e is PostgrestException) {
      switch (e.code) {
        case '42501':
          return tr('tx_err_42501');
        case '23503':
          return tr('tx_err_23503');
        case '23514':
          return tr('tx_err_23514');
        case '23505':
          return tr('tx_err_23505');
        case 'PGRST116':
          return tr('tx_err_pgrst').replaceFirst('{a}', action);
        default:
          return tr('tx_err_code')
              .replaceFirst('{a}', action)
              .replaceFirst('{c}', e.code ?? 'error');
      }
    }
    return tr('tx_err_generic').replaceFirst('{a}', action);
  }

  Future<void> _confirmDelete() async {
    if (editing == null) return;
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
    if (ok != true || !mounted || editing == null) return;
    try {
      final orgId = await activeOrgId();
      await TransactionService().delete(editing!.id, orgId);
      if (!mounted) return;
      _cancelEdit();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('tx_deleted'))));
      await _load();
    } catch (e) {
      if (!mounted) return;
      debugPrint('delete tx: $e');
      setState(() => formErr = _txError(e, tr('tx_act_del')));
    }
  }

  void _scrollToForm() {
    final ctx = formKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: SsrMotion.base,
        curve: SsrMotion.curve,
      );
    }
  }

  void _onMonthChanged(String m) {
    setState(() => month = m);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (noOrg) {
      return _TxStateScaffold(
        EmptyView(
          icon: AppIcons.workspace,
          title: tr('tx_no_org_t'),
          subtitle: tr('tx_no_org_s'),
          actionLabel: tr('reload'),
          onAction: _load,
        ),
      );
    }
    if (loading) {
      return const _TxStateScaffold(TxListSkeleton());
    }
    if (err != null) {
      return _TxStateScaffold(ErrorView(message: err!, onRetry: _load));
    }
    return _TxStateScaffold(
      _TxListBody(
        month: month,
        onMonthChanged: _onMonthChanged,
        items: items,
        selectedId: editing?.id,
        onTap: _startEdit,
        onEmptyAction: _scrollToForm,
        formKey: formKey,
        editing: editing,
        type: type,
        amountC: amountC,
        catC: catC,
        noteC: noteC,
        walletId: walletId,
        toWalletId: toWalletId,
        wallets: wallets,
        balanceOf: _balanceOf,
        formErr: formErr,
        saving: saving,
        onTypeChanged: (v) => setState(() => type = v),
        onWalletChanged: (v) => setState(() => walletId = v),
        onToWalletChanged: (v) => setState(() => toWalletId = v),
        onCancelEdit: _cancelEdit,
        onConfirmDelete: _confirmDelete,
        onSave: _save,
      ),
    );
  }
}

/// Kartu form "Catat transaksi": banner edit, pil jenis, field nominal /
/// kategori / catatan, dropdown dompet (transfer punya dompet tujuan),
/// pesan galat, dan tombol simpan (+ hapus saat mode edit).
class _TxFormCard extends StatelessWidget {
  final GlobalKey formKey;
  final SaasTransaction? editing;
  final String type;
  final TextEditingController amountC;
  final TextEditingController catC;
  final TextEditingController noteC;
  final String? walletId;
  final String? toWalletId;
  final List<Wallet> wallets;
  final double? Function(String? id) balanceOf;
  final String? formErr;
  final bool saving;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String?> onWalletChanged;
  final ValueChanged<String?> onToWalletChanged;
  final VoidCallback onCancelEdit;
  final VoidCallback onConfirmDelete;
  final VoidCallback onSave;

  const _TxFormCard({
    required this.formKey,
    required this.editing,
    required this.type,
    required this.amountC,
    required this.catC,
    required this.noteC,
    required this.walletId,
    required this.toWalletId,
    required this.wallets,
    required this.balanceOf,
    required this.formErr,
    required this.saving,
    required this.onTypeChanged,
    required this.onWalletChanged,
    required this.onToWalletChanged,
    required this.onCancelEdit,
    required this.onConfirmDelete,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (editing != null) ...[
            _EditBanner(
              label: tr('tx_editing')
                  .replaceFirst('{c}', editing!.code ?? tr('tx_editing_tx')),
              onCancelEdit: onCancelEdit,
            ),
            const SizedBox(height: SsrSpace.md),
          ],
          Text(
            editing != null ? tr('tx_form_edit') : tr('tx_form_add'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: SsrSpace.md),
          TxTypeSelector(value: type, onChanged: onTypeChanged),
          const SizedBox(height: SsrSpace.lg),
          _TxBasicFields(amountC: amountC, catC: catC, noteC: noteC),
          _TxDropdowns(
            type: type,
            walletId: walletId,
            toWalletId: toWalletId,
            wallets: wallets,
            balanceOf: balanceOf,
            formErr: formErr,
            onWalletChanged: onWalletChanged,
            onToWalletChanged: onToWalletChanged,
          ),
          const SizedBox(height: SsrSpace.lg),
          _TxFormActions(
            editing: editing,
            saving: saving,
            onSave: onSave,
            onConfirmDelete: onConfirmDelete,
          ),
        ],
      ),
    );
  }
}

/// Blok riwayat: judul bulan + daftar TxRow (atau EmptyView bila kosong).
class _TxHistorySection extends StatelessWidget {
  final String month;
  final List<SaasTransaction> items;
  final String? selectedId;
  final ValueChanged<SaasTransaction> onTap;
  final VoidCallback onEmptyAction;

  const _TxHistorySection({
    required this.month,
    required this.items,
    required this.selectedId,
    required this.onTap,
    required this.onEmptyAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          txHistoryTitle(month),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: SsrSpace.sm),
        if (items.isEmpty)
          SizedBox(
            height: 260,
            child: EmptyView(
              icon: AppIcons.transactions,
              illustration: 'assets/illustrations/empty_riwayat.svg',
              title: tr('tx_empty_t'),
              subtitle: tr('tx_empty_s'),
              actionLabel: tr('tx_empty_a'),
              onAction: onEmptyAction,
            ),
          )
        else
          for (final t in items) ...[
            TxRow(tx: t, selected: selectedId == t.id, onTap: () => onTap(t)),
            const Divider(height: 1),
          ],
      ],
    );
  }
}

/// Kerangka layar Transaksi: AppBar "Transaksi" + body (state / daftar).
class _TxStateScaffold extends StatelessWidget {
  final Widget body;
  const _TxStateScaffold(this.body);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('nav_transaksi'))),
      body: body,
    );
  }
}

/// Isi layar Transaksi: pemilih bulan, kartu form catat, dan blok riwayat.
class _TxListBody extends StatelessWidget {
  final String month;
  final ValueChanged<String> onMonthChanged;
  final List<SaasTransaction> items;
  final String? selectedId;
  final ValueChanged<SaasTransaction> onTap;
  final VoidCallback onEmptyAction;
  final GlobalKey formKey;
  final SaasTransaction? editing;
  final String type;
  final TextEditingController amountC;
  final TextEditingController catC;
  final TextEditingController noteC;
  final String? walletId;
  final String? toWalletId;
  final List<Wallet> wallets;
  final double? Function(String? id) balanceOf;
  final String? formErr;
  final bool saving;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String?> onWalletChanged;
  final ValueChanged<String?> onToWalletChanged;
  final VoidCallback onCancelEdit;
  final VoidCallback onConfirmDelete;
  final VoidCallback onSave;

  const _TxListBody({
    required this.month,
    required this.onMonthChanged,
    required this.items,
    required this.selectedId,
    required this.onTap,
    required this.onEmptyAction,
    required this.formKey,
    required this.editing,
    required this.type,
    required this.amountC,
    required this.catC,
    required this.noteC,
    required this.walletId,
    required this.toWalletId,
    required this.wallets,
    required this.balanceOf,
    required this.formErr,
    required this.saving,
    required this.onTypeChanged,
    required this.onWalletChanged,
    required this.onToWalletChanged,
    required this.onCancelEdit,
    required this.onConfirmDelete,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SsrSpace.lg,
        SsrSpace.lg,
        SsrSpace.lg,
        96,
      ),
      children: [
        MonthPicker(month: month, onChanged: onMonthChanged),
        const SizedBox(height: SsrSpace.md),
        _TxFormCard(
          formKey: formKey,
          editing: editing,
          type: type,
          amountC: amountC,
          catC: catC,
          noteC: noteC,
          walletId: walletId,
          toWalletId: toWalletId,
          wallets: wallets,
          balanceOf: balanceOf,
          formErr: formErr,
          saving: saving,
          onTypeChanged: onTypeChanged,
          onWalletChanged: onWalletChanged,
          onToWalletChanged: onToWalletChanged,
          onCancelEdit: onCancelEdit,
          onConfirmDelete: onConfirmDelete,
          onSave: onSave,
        ),
        const SizedBox(height: SsrSpace.xl),
        _TxHistorySection(
          month: month,
          items: items,
          selectedId: selectedId,
          onTap: onTap,
          onEmptyAction: onEmptyAction,
        ),
      ],
    );
  }
}

/// Banner "Mengubah TX-xxxx" + tombol Batalkan edit (saat mode edit).
class _EditBanner extends StatelessWidget {
  final String label;
  final VoidCallback onCancelEdit;

  const _EditBanner({required this.label, required this.onCancelEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SsrSpace.md),
      decoration: BoxDecoration(
        color: SsrColors.accentSoft,
        borderRadius: BorderRadius.circular(SsrRadius.tile),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          TextButton(
            onPressed: onCancelEdit,
            child: Text(tr('tx_cancel_edit')),
          ),
        ],
      ),
    );
  }
}

/// Tiga field teks form: nominal, kategori, dan catatan.
class _TxBasicFields extends StatelessWidget {
  final TextEditingController amountC;
  final TextEditingController catC;
  final TextEditingController noteC;

  const _TxBasicFields({
    required this.amountC,
    required this.catC,
    required this.noteC,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: amountC,
          keyboardType: TextInputType.number,
          style: SsrTheme.moneyLarge,
          decoration: InputDecoration(
            labelText: tr('tx_f_nominal'),
            prefixText: '${kCurrencySymbols[currencyCode.value] ?? 'Rp'} ',
            prefixStyle: SsrTheme.moneyLarge,
          ),
        ),
        const SizedBox(height: SsrSpace.md),
        TextField(
          controller: catC,
          decoration: InputDecoration(labelText: tr('tx_f_cat')),
        ),
        const SizedBox(height: SsrSpace.sm),
        CategoryChips(controller: catC),
        const SizedBox(height: SsrSpace.md),
        TextField(
          controller: noteC,
          decoration: InputDecoration(labelText: tr('tx_f_note')),
        ),
      ],
    );
  }
}

/// Pilihan dompet (+ dompet tujuan saat transfer) dan pesan galat.
class _TxDropdowns extends StatelessWidget {
  final String type;
  final String? walletId;
  final String? toWalletId;
  final List<Wallet> wallets;
  final double? Function(String? id) balanceOf;
  final String? formErr;
  final ValueChanged<String?> onWalletChanged;
  final ValueChanged<String?> onToWalletChanged;

  const _TxDropdowns({
    required this.type,
    required this.walletId,
    required this.toWalletId,
    required this.wallets,
    required this.balanceOf,
    required this.formErr,
    required this.onWalletChanged,
    required this.onToWalletChanged,
  });

  DropdownMenuItem<String> _walletItem(Wallet w, ThemeData theme) {
    final bal = balanceOf(w.id);
    return DropdownMenuItem(
      value: w.id,
      child: Text(
        bal == null ? w.name : '${w.name} · ${amt(bal)}',
        style: bal == null
            ? null
            : theme.textTheme.bodyMedium?.copyWith(
                color: SsrColors.secondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: SsrSpace.md),
        DropdownButtonFormField<String>(
          initialValue: walletId,
          decoration: InputDecoration(labelText: tr('tx_f_wallet')),
          items: [for (final w in wallets) _walletItem(w, theme)],
          onChanged: onWalletChanged,
        ),
        if (type == 'transfer') ...[
          const SizedBox(height: SsrSpace.md),
          DropdownButtonFormField<String>(
            initialValue: toWalletId,
            decoration: InputDecoration(labelText: tr('tx_f_towallet')),
            items: [for (final w in wallets) _walletItem(w, theme)],
            onChanged: onToWalletChanged,
          ),
        ],
        if (formErr != null) ...[
          const SizedBox(height: SsrSpace.md),
          Text(
            formErr!,
            style: const TextStyle(color: SsrColors.danger, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

/// Tombol simpan (+ Hapus danger saat mode edit).
class _TxFormActions extends StatelessWidget {
  final SaasTransaction? editing;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onConfirmDelete;

  const _TxFormActions({
    required this.editing,
    required this.saving,
    required this.onSave,
    required this.onConfirmDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          label: editing != null ? tr('tx_save_edit') : tr('tx_save_add'),
          onPressed: onSave,
          loading: saving,
        ),
        if (editing != null) ...[
          const SizedBox(height: SsrSpace.sm),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: onConfirmDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: SsrColors.danger,
                side: const BorderSide(color: SsrColors.danger),
              ),
              child: Text(tr('tx_delete')),
            ),
          ),
        ],
      ],
    );
  }
}
