import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/services/debt_track.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:ssr_space/widgets/tx_type_selector.dart';

/// Kunci prefs daftar utang-piutang (maks [maxDebts]).
const _kDebts = 'debts';

Future<List<DebtRecord>> loadDebts() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kDebts);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    final out = <DebtRecord>[];
    for (final e in list) {
      final d = DebtRecord.tryParse(e);
      if (d != null) out.add(d);
      if (out.length >= maxDebts) break;
    }
    return out;
  } catch (_) {
    return [];
  }
}

Future<void> saveDebts(List<DebtRecord> debts) async {
  final capped = debts.take(maxDebts).toList();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _kDebts,
    jsonEncode([for (final d in capped) d.toJson()]),
  );
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Daftar utang & piutang pribadi (simpan lokal HP).
class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => DebtsScreenState();
}

class DebtsScreenState extends State<DebtsScreen> {
  bool loading = true;
  bool loadFailed = false;
  List<DebtRecord> debts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadFailed = false;
    });
    try {
      final list = await loadDebts();
      if (!mounted) return;
      setState(() {
        loading = false;
        debts = list;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          loadFailed = true;
        });
      }
    }
  }

  Future<void> _update(DebtRecord next) async {
    final list = [for (final d in debts) d.id == next.id ? next : d];
    await saveDebts(list);
    if (mounted) setState(() => debts = list);
  }

  Future<void> _remove(String id) async {
    final list = debts.where((d) => d.id != id).toList();
    await saveDebts(list);
    if (mounted) setState(() => debts = list);
  }

  Future<void> _create() async {
    final made = await showModalBottomSheet<DebtRecord>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DebtEditor(),
    );
    if (made == null) return;
    if (debts.length >= maxDebts) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('db_full'))));
      return;
    }
    final list = [...debts, made];
    await saveDebts(list);
    if (!mounted) return;
    setState(() => debts = list);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('db_saved'))));
  }

  Future<void> _openDetail(DebtRecord d) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DebtDetailSheet(
        record: d,
        onChanged: _update,
        onDelete: () => _remove(d.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('db_title'))),
      floatingActionButton: (loading || loadFailed)
          ? null
          : FloatingActionButton(
              onPressed: _create,
              child: const DuoIcon(AppIcons.add),
            ),
      body: _body(),
    );
  }

  Widget _body() {
    if (loading) return const TxListSkeleton();
    if (loadFailed) {
      return ErrorView(message: tr('tx_err_load'), onRetry: _load);
    }
    if (debts.isEmpty) {
      return EmptyView(
        icon: AppIcons.billing,
        title: tr('db_empty_t'),
        subtitle: tr('db_empty_s'),
        actionLabel: tr('db_new'),
        onAction: _create,
      );
    }
    final t = debtTotals(debts);
    return ListView.builder(
      padding: const EdgeInsets.all(SsrSpace.lg),
      itemCount: debts.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _TotalCard(debt: t.debt, receivable: t.receivable);
        return _DebtTile(record: debts[i - 1], onTap: _openDetail);
      },
    );
  }
}

/// Kartu total sisa utang vs piutang.
class _TotalCard extends StatelessWidget {
  final double debt;
  final double receivable;

  const _TotalCard({required this.debt, required this.receivable});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Row(
        children: [
          Expanded(child: _totalCell(context, tr('db_total_debt'), debt)),
          Expanded(child: _totalCell(context, tr('db_total_rec'), receivable)),
        ],
      ),
    );
  }

  Widget _totalCell(BuildContext context, String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          amt(value),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Satu baris catatan: nama, sisa/total, chip jenis.
class _DebtTile extends StatelessWidget {
  final DebtRecord record;
  final ValueChanged<DebtRecord> onTap;

  const _DebtTile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = record.isSettled;
    final chip = done
        ? tr('db_done')
        : record.kind == debtKindDebt
        ? tr('db_debt')
        : tr('db_receivable');
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: InkWell(
        onTap: () => onTap(record),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    done
                        ? '${amt(record.total)} · $chip'
                        : '${tr('db_rest').replaceFirst('{m}', amt(record.remaining()))} / ${amt(record.total)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            StatusChip(
              label: chip,
              tone: done
                  ? StatusTone.neutral
                  : record.kind == debtKindDebt
                  ? StatusTone.danger
                  : StatusTone.accent,
            ),
          ],
        ),
      ),
    );
  }
}

/// Isi detail catatan: info + bayar + riwayat + hapus.
class _DebtDetailSheet extends StatefulWidget {
  final DebtRecord record;
  final ValueChanged<DebtRecord> onChanged;
  final VoidCallback onDelete;

  const _DebtDetailSheet({
    required this.record,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_DebtDetailSheet> createState() => _DebtDetailSheetState();
}

class _DebtDetailSheetState extends State<_DebtDetailSheet> {
  late DebtRecord debt;

  @override
  void initState() {
    super.initState();
    debt = widget.record;
  }

  Future<void> _pay() async {
    if (debt.isSettled || !mounted) return;
    final amountC = TextEditingController(
      text: debt.remaining().toStringAsFixed(0),
    );
    try {
      final v = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('db_pay')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('db_pay_hint')),
              const SizedBox(height: SsrSpace.sm),
              TextField(
                controller: amountC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('rb_amount')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel')),
            ),
            TextButton(
              onPressed: () {
                final t = double.tryParse(amountC.text.trim());
                if (t == null) {
                  Navigator.pop(ctx);
                  return;
                }
                Navigator.pop(ctx, t);
              },
              child: Text(tr('save')),
            ),
          ],
        ),
      );
      if (v == null || !mounted) return;
      final problem = validatePayment(debt, v);
      if (problem != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              problem == 'over'
                  ? tr('db_err_over')
                        .replaceFirst('{m}', amt(debt.remaining()))
                  : tr('tx_err_amount'),
            ),
          ),
        );
        return;
      }
      final now = DateTime.now();
      final updated = debt.applyPayment(
        DebtPayment(amount: v, date: _ymd(now)),
      );
      setState(() => debt = updated);
      widget.onChanged(updated);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('db_paid_ok'))));
      }
    } finally {
      amountC.dispose();
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('db_del_t')),
        content: Text(tr('db_del_s')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('tx_delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    widget.onDelete();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _head(context),
            const SizedBox(height: SsrSpace.sm),
            _history(context),
            if (!debt.isSettled) ...[
              const SizedBox(height: SsrSpace.md),
              FilledButton(onPressed: _pay, child: Text(tr('db_pay'))),
            ],
            TextButton(
              onPressed: _confirmDelete,
              child: Text(
                tr('tx_delete'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _head(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                debt.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            StatusChip(
              label: debt.kind == debtKindDebt
                  ? tr('db_debt')
                  : tr('db_receivable'),
              tone: debt.kind == debtKindDebt
                  ? StatusTone.danger
                  : StatusTone.accent,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${tr('db_paid').replaceFirst('{m}', amt(debt.paidTotal))} · '
          '${tr('db_rest').replaceFirst('{m}', amt(debt.remaining()))} / ${amt(debt.total)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          debt.date + (debt.note.isEmpty ? '' : ' · ${debt.note}'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _history(BuildContext context) {
    if (debt.payments.isEmpty) {
      return Text(
        tr('db_empty_pay'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final rows = debt.payments.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('rb_history'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final p in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(p.date)),
                Text(
                  amt(p.amount),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Form tambah catatan: jenis + nama + nominal + tanggal + catatan.
class _DebtEditor extends StatefulWidget {
  const _DebtEditor();

  @override
  State<_DebtEditor> createState() => _DebtEditorState();
}

class _DebtEditorState extends State<_DebtEditor> {
  final nameC = TextEditingController();
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  String kind = debtKindDebt;
  DateTime date = DateTime.now();
  String? err;

  @override
  void dispose() {
    nameC.dispose();
    amountC.dispose();
    noteC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && mounted) setState(() => date = picked);
  }

  void _submit() {
    final name = nameC.text.trim();
    final amount = double.tryParse(amountC.text.trim());
    if (name.isEmpty || amount == null || amount <= 0) {
      setState(() => err = tr('tx_err_amount'));
      return;
    }
    Navigator.pop(
      context,
      DebtRecord(
        id: newDebtId(),
        kind: kind,
        name: name.length > 40 ? name.substring(0, 40) : name,
        total: amount,
        date: _ymd(date),
        note: noteC.text.trim(),
        payments: const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          SsrSpace.lg,
          SsrSpace.lg,
          SsrSpace.lg,
          MediaQuery.of(context).viewInsets.bottom + SsrSpace.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('db_new'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: SsrSpace.md),
            _kindSegment(),
            const SizedBox(height: 2),
            Text(
              kind == debtKindDebt ? tr('db_debt_h') : tr('db_receivable_h'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: SsrSpace.sm),
            TextField(
              controller: nameC,
              decoration: InputDecoration(labelText: tr('db_name')),
            ),
            const SizedBox(height: SsrSpace.sm),
            TextField(
              controller: amountC,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('rb_amount')),
            ),
            const SizedBox(height: SsrSpace.sm),
            _dateRow(context),
            const SizedBox(height: SsrSpace.sm),
            TextField(
              controller: noteC,
              decoration: InputDecoration(labelText: tr('db_note')),
            ),
            if (err != null) ...[
              const SizedBox(height: SsrSpace.sm),
              Text(
                err!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: SsrSpace.md),
            FilledButton(onPressed: _submit, child: Text(tr('save'))),
          ],
        ),
      ),
    );
  }

  Widget _kindSegment() {
    return SegmentedButton<String>(
      style: ssrSegmentedStyle(context),
      segments: [
        ButtonSegment(value: debtKindDebt, label: Text(tr('db_debt'))),
        ButtonSegment(value: debtKindReceivable, label: Text(tr('db_receivable'))),
      ],
      selected: {kind},
      showSelectedIcon: false,
      onSelectionChanged: (s) => setState(() => kind = s.first),
    );
  }

  Widget _dateRow(BuildContext context) {
    return InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: InputDecoration(labelText: tr('tx_f_date')),
        child: Text(_ymd(date)),
      ),
    );
  }
}
