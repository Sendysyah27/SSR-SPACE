import 'package:flutter/material.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/app_settings.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/services/currency.dart';
import 'package:ssr_space/services/quick_input_parse.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/tx_input_logic.dart';
import 'package:ssr_space/services/tx_validation.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/services/wallet_usage.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/datetime.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/category_chips.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/success_lottie.dart';
import 'package:ssr_space/widgets/tx_numpad.dart';
import 'package:ssr_space/widgets/tx_type_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pintu masuk tunggal catat/ubah transaksi dari mana pun:
/// tombol + tengah navbar, aksi + AppBar riwayat, ketuk TxRow (edit).
/// Memuat workspace + dompet sendiri, buka sheet, beri umpan balik,
/// kembalikan true bila pemanggil perlu muat ulang.
Future<bool> openTxInputSheet(
  BuildContext context, {
  SaasTransaction? editing,
  String? initialType,
  double? initialAmountIdr,
  String? initialCategory,
  String? initialWalletId,
  String? initialNote,
}) async {
  final orgId = await activeOrgId();
  if (orgId.isEmpty || !context.mounted) return false;
  late final List<Wallet> wallets;
  Map<String, double> balances = {};
  try {
    wallets = await WalletService().list(orgId);
    try {
      final bals = await WalletService().balances(orgId);
      balances = {for (final b in bals) b.walletId: b.balance};
    } catch (_) {
      balances = {};
    }
  } catch (_) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('conn_error'))));
    return false;
  }
  if (!context.mounted) return false;
  final res = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => TxInputSheet(
      orgId: orgId,
      wallets: wallets,
      balances: balances,
      editing: editing,
      initialType: initialType,
      initialAmountIdr: initialAmountIdr,
      initialCategory: initialCategory,
      initialWalletId: initialWalletId,
      initialNote: initialNote,
    ),
  );
  if (!context.mounted || res == null) return false;
  if (res == 'deleted') {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('tx_deleted'))));
  } else if (editing != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('tx_updated'))));
  } else {
    await showSuccessFlash(context);
  }
  return true;
}

/// Sheet input transaksi premium: display nominal + numpad custom,
/// jenis, tanggal (wajib) + jam (opsional), dompet, kategori, catatan.
/// Keyboard sistem hanya muncul untuk kategori/catatan; nominal murni numpad.
class TxInputSheet extends StatefulWidget {
  final String orgId;
  final List<Wallet> wallets;
  final Map<String, double> balances;
  final SaasTransaction? editing;

  /// Prefill untuk saran tagihan rutin (dipakai bila [editing] null).
  final String? initialType;
  final double? initialAmountIdr;
  final String? initialCategory;
  final String? initialWalletId;
  final String? initialNote;

  const TxInputSheet({
    super.key,
    required this.orgId,
    required this.wallets,
    required this.balances,
    this.editing,
    this.initialType,
    this.initialAmountIdr,
    this.initialCategory,
    this.initialWalletId,
    this.initialNote,
  });

  @override
  State<TxInputSheet> createState() => _TxInputSheetState();
}

class _TxInputSheetState extends State<TxInputSheet> {
  late String type;
  late final ValueNotifier<String> digits;
  late DateTime day;
  late bool useTime;
  late TimeOfDay time;
  String? walletId;
  String? toWalletId;
  final quickC = TextEditingController();
  final catC = TextEditingController();
  final subC = TextEditingController();
  final noteC = TextEditingController();
  bool saving = false;
  String? formErr;

  int get _dec => kCurrencyDecimals(currencyCode.value);
  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    type = e?.type ?? widget.initialType ?? 'out';
    final major0 = e == null
        ? (widget.initialAmountIdr == null
              ? 0.0
              : CurrencyService.convert(widget.initialAmountIdr!))
        : CurrencyService.convert(e.amount);
    digits = ValueNotifier(digitsFromMajor(major0, dec: _dec));
    day = e?.date != null
        ? DateTime.tryParse(e!.date!) ?? DateTime.now()
        : DateTime.now();
    final t = txCreatedAtTime(e?.createdAt);
    useTime = t != null;
    time = t == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: t.hour, minute: t.minute);
    walletId = e?.walletId ?? widget.initialWalletId;
    toWalletId = e?.toWalletId;
    catC.text = e?.category != null
        ? parseCategory(e!.category!).top
        : (widget.initialCategory ?? '');
    subC.text = e?.category != null
        ? (parseCategory(e!.category!).sub ?? '')
        : '';
    noteC.text = e?.note ?? widget.initialNote ?? '';
  }

  @override
  void dispose() {
    digits.dispose();
    quickC.dispose();
    catC.dispose();
    subC.dispose();
    noteC.dispose();
    super.dispose();
  }

  double get _idr =>
      CurrencyService.toIdr(majorFromDigits(digits.value, dec: _dec));

  /// Ketik cepat: urai teks bebas lalu prefill form (tambah saja).
  /// Tanpa nominal valid = abaikan; tak pernah menimpa saat mode edit.
  /// Simpan tetap lewat tombol (tak ada insert diam-diam).
  void _applyQuick(String v) {
    if (_isEdit || v.trim().isEmpty) return;
    final q = parseQuickInput(
      v,
      categories: appCategories.value,
      wallets: [for (final w in widget.wallets) w.name],
    );
    if (q == null) return;
    setState(() {
      type = q.type;
      digits.value = digitsFromMajor(
        CurrencyService.convert(q.amount),
        dec: _dec,
      );
      if (q.category != null) catC.text = q.category!;
      if (q.walletName != null) {
        final low = q.walletName!.toLowerCase();
        for (final w in widget.wallets) {
          if (w.name.trim().toLowerCase() == low) {
            walletId = w.id;
            break;
          }
        }
      }
      noteC.text = q.note;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => day = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: time);
    if (picked != null) setState(() => time = picked);
  }

  Future<void> _save() async {
    final v = validateTxInput(
      amount: _idr,
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
      final when = txWhen(
        day,
        hour: useTime ? time.hour : null,
        minute: useTime ? time.minute : null,
      );
      final top = catC.text.trim();
      final sub = subC.text.trim();
      if (sub.contains('>') || top.contains('>')) {
        if (!mounted) return;
        setState(() {
          saving = false;
          formErr = tr('sub_sep_err');
        });
        return;
      }
      final cat = top.isEmpty
          ? null
          : (sub.isEmpty ? top : formatCategory(top, sub));
      final note = noteC.text.trim();
      final svc = TransactionService();
      if (_isEdit) {
        await svc.update(
          id: widget.editing!.id,
          orgId: widget.orgId,
          type: type,
          amount: _idr,
          walletId: walletId,
          toWalletId: type == 'transfer' ? toWalletId : null,
          category: cat,
          note: note.isEmpty ? null : note,
          date: when.date,
          createdAt: when.createdAt,
        );
      } else {
        await svc.add(
          orgId: widget.orgId,
          type: type,
          amount: _idr,
          walletId: walletId,
          toWalletId: type == 'transfer' ? toWalletId : null,
          category: cat,
          note: note,
          date: when.date,
          createdAt: when.createdAt,
        );
      }
      try {
        if (walletId != null) await noteWalletUsed(walletId!);
        if (type == 'transfer' && toWalletId != null) {
          await noteWalletUsed(toWalletId!);
        }
      } catch (_) {}
      if (!mounted) return;
      Navigator.pop(context, 'saved');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        formErr = _txError(e);
      });
    }
  }

  String _txError(Object e) {
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
      }
    }
    return tr('tx_err_generic').replaceFirst('{a}', tr('tx_act_save'));
  }

  Future<void> _confirmDelete() async {
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
    try {
      await TransactionService().delete(widget.editing!.id, widget.orgId);
      if (!mounted) return;
      Navigator.pop(context, 'deleted');
    } catch (e) {
      if (!mounted) return;
      setState(() => formErr = _txError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: SsrSpace.lg,
          right: SsrSpace.lg,
          top: SsrSpace.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + SsrSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _DragHandle(),
            _SheetHeader(
              isEdit: _isEdit,
              code: widget.editing?.code,
              onClose: () => Navigator.pop(context),
            ),
            if (!_isEdit) ...[
              const SizedBox(height: SsrSpace.sm),
              _QuickSection(controller: quickC, onChanged: _applyQuick),
            ],
            _AmountDisplay(digits: digits, dec: _dec),
            TxTypeSelector(
              value: type,
              onChanged: (v) => setState(() => type = v),
            ),
            const SizedBox(height: SsrSpace.sm),
            TxNumpad(digits: digits),
            const SizedBox(height: SsrSpace.sm),
            _DateTimeSection(
              day: day,
              useTime: useTime,
              time: time,
              onPickDate: _pickDate,
              onToggleTime: (v) => setState(() => useTime = v),
              onPickTime: _pickTime,
            ),
            _WalletSection(
              type: type,
              walletId: walletId,
              toWalletId: toWalletId,
              wallets: widget.wallets,
              balances: widget.balances,
              onWalletChanged: (v) => setState(() => walletId = v),
              onToWalletChanged: (v) => setState(() => toWalletId = v),
            ),
            _MetaSection(catC: catC, subC: subC, noteC: noteC),
            if (formErr != null) ...[
              const SizedBox(height: SsrSpace.sm),
              Text(
                formErr!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: SsrSpace.md),
            PrimaryButton(
              label: _isEdit ? tr('tx_save_edit') : tr('tx_save_add'),
              onPressed: _save,
              loading: saving,
            ),
            if (_isEdit) ...[
              const SizedBox(height: SsrSpace.sm),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _confirmDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  child: Text(tr('tx_delete')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gagang drag sheet (motif ledger: garis pendek di tengah).
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: SsrSpace.sm),
        decoration: BoxDecoration(
          color: scheme.outline,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Judul sheet + tombol tutup. Mode edit menampilkan kode TX.
class _SheetHeader extends StatelessWidget {
  final bool isEdit;
  final String? code;
  final VoidCallback onClose;

  const _SheetHeader({
    required this.isEdit,
    required this.code,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? tr('tx_form_edit') : tr('tx_form_add'),
                style: theme.textTheme.titleMedium,
              ),
              if (isEdit && code != null)
                Text(
                  code!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const DuoIcon(AppIcons.close),
          tooltip: tr('back'),
        ),
      ],
    );
  }
}

/// Ketik cepat: satu baris teks bebas yang diparse live menjadi prefill.
/// Murni jalan pintas pengisi; validasi + simpan tetap lewat alur biasa.
class _QuickSection extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _QuickSection({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: tr('tx_quick_hint'),
        prefixIcon: const DuoIcon(AppIcons.search, size: 20),
      ),
    );
  }
}

/// Display nominal besar: ikut tiap ketukan numpad, format mata uang aktif.
class _AmountDisplay extends StatelessWidget {
  final ValueNotifier<String> digits;
  final int dec;

  const _AmountDisplay({required this.digits, required this.dec});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: digits,
      builder: (_, d, __) {
        final idr =
            CurrencyService.toIdr(majorFromDigits(d, dec: dec));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: SsrSpace.md),
          child: Text(
            CurrencyService.format(idr),
            style: AppTheme.moneyLarge,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}

/// Baris tanggal (selalu ada, default hari ini) + switch jam opsional.
class _DateTimeSection extends StatelessWidget {
  final DateTime day;
  final bool useTime;
  final TimeOfDay time;
  final VoidCallback onPickDate;
  final ValueChanged<bool> onToggleTime;
  final VoidCallback onPickTime;

  const _DateTimeSection({
    required this.day,
    required this.useTime,
    required this.time,
    required this.onPickDate,
    required this.onToggleTime,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('tx_f_date'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            OutlinedButton.icon(
              onPressed: onPickDate,
              icon: const DuoIcon(AppIcons.calendar, size: 18),
              label: Text(dayLabel(txYmd(day))),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                tr('tx_add_time'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Switch(value: useTime, onChanged: onToggleTime),
            if (useTime)
              OutlinedButton.icon(
                onPressed: onPickTime,
                icon: const DuoIcon(AppIcons.clock, size: 18),
                label: Text(
                  '${time.hour.toString().padLeft(2, '0')}:'
                  '${time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Dropdown dompet (+ tujuan saat transfer), label ikut saldo mask-aware.
class _WalletSection extends StatelessWidget {
  final String type;
  final String? walletId;
  final String? toWalletId;
  final List<Wallet> wallets;
  final Map<String, double> balances;
  final ValueChanged<String?> onWalletChanged;
  final ValueChanged<String?> onToWalletChanged;

  const _WalletSection({
    required this.type,
    required this.walletId,
    required this.toWalletId,
    required this.wallets,
    required this.balances,
    required this.onWalletChanged,
    required this.onToWalletChanged,
  });

  DropdownMenuItem<String> _item(Wallet w, ThemeData theme) {
    final bal = balances[w.id];
    final muted = theme.textTheme.bodySmall?.color;
    return DropdownMenuItem(
      value: w.id,
      child: Text(
        bal == null ? w.name : '${w.name} · ${amt(bal)}',
        style: bal == null
            ? null
            : theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: walletUseCounts,
      builder: (_, counts, __) {
        final names = <String, String>{
          for (final w in wallets) w.id: w.name,
        };
        final byId = <String, Wallet>{for (final w in wallets) w.id: w};
        final ordered = [
          for (final id in sortIdsByUse(counts, names)) byId[id]!,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: SsrSpace.sm),
            DropdownButtonFormField<String>(
              initialValue: walletId,
              decoration: InputDecoration(labelText: tr('tx_f_wallet')),
              items: [for (final w in ordered) _item(w, theme)],
              onChanged: onWalletChanged,
            ),
            if (type == 'transfer') ...[
              const SizedBox(height: SsrSpace.md),
              DropdownButtonFormField<String>(
                initialValue: toWalletId,
                decoration: InputDecoration(labelText: tr('tx_f_towallet')),
                items: [for (final w in ordered) _item(w, theme)],
                onChanged: onToWalletChanged,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Kategori (field + chip pintasan), subkategori opsional, dan catatan.
class _MetaSection extends StatelessWidget {
  final TextEditingController catC;
  final TextEditingController subC;
  final TextEditingController noteC;

  const _MetaSection({
    required this.catC,
    required this.subC,
    required this.noteC,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: SsrSpace.md),
        TextField(
          controller: catC,
          decoration: InputDecoration(labelText: tr('tx_f_cat')),
        ),
        const SizedBox(height: SsrSpace.sm),
        CategoryChips(controller: catC),
        const SizedBox(height: SsrSpace.sm),
        TextField(
          controller: subC,
          decoration: InputDecoration(labelText: tr('sub_hint')),
        ),
        const SizedBox(height: SsrSpace.md),
        TextField(
          controller: noteC,
          decoration: InputDecoration(labelText: tr('tx_f_note')),
        ),
      ],
    );
  }
}
