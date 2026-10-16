import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ssr_space/services/billing_service.dart';
import 'package:ssr_space/services/debt_store.dart';
import 'package:ssr_space/services/debt_track.dart';
import 'package:ssr_space/services/due_notify.dart';
import 'package:ssr_space/services/due_reminder.dart';
import 'package:ssr_space/services/plan_limits.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:ssr_space/widgets/tx_type_selector.dart';

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
    unawaited(DueNotify.reschedule());
  }

  Future<void> _remove(String id) async {
    final list = debts.where((d) => d.id != id).toList();
    await saveDebts(list);
    if (mounted) setState(() => debts = list);
    unawaited(DueNotify.reschedule());
  }

  Future<void> _create() async {
    // Gate Gratis sebelum editor dibuka: catatan ke-(freeDebts+1) →
    // paywall. Stale (offline/RPC-gagal) → izinkan. Cap teknis
    // maxDebts tetap di bawah (pesan db_full untuk Pro penuh).
    if (debts.length >= PlanLimits.freeDebts) {
      final orgId = await activeOrgId();
      final st = await planStatus(orgId);
      final blocked = st['stale'] != true &&
          !canAddDebt(
            plan: (st['plan'] ?? 'free').toString(),
            used: debts.length,
          );
      if (blocked) {
        if (!mounted) return;
        await requirePro(context, tr('bl_limit_debts'));
        return;
      }
    }
    if (!mounted) return;
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
    unawaited(DueNotify.reschedule());
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
        illustration: 'assets/illustrations/empty_dompet.svg',
        title: tr('db_empty_t'),
        subtitle: tr('db_empty_s'),
        actionLabel: tr('db_new'),
        onAction: _create,
      );
    }
    final t = debtTotals(debts);
    final now = DateTime.now();
    final upcoming = [
      for (final d in debtDues(debts, now))
        if (d.daysLeft <= 7) d,
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(SsrSpace.lg),
      itemCount: debts.length + 1 + (upcoming.isEmpty ? 0 : 1),
      itemBuilder: (_, i) {
        if (i == 0) return _TotalCard(debt: t.debt, receivable: t.receivable);
        if (upcoming.isNotEmpty && i == 1) {
          return _UpcomingCard(
            dues: upcoming,
            onTap: _openDetailRecord,
          );
        }
        final idx = i - 1 - (upcoming.isEmpty ? 0 : 1);
        return _DebtTile(record: debts[idx], onTap: _openDetail);
      },
    );
  }

  void _openDetailRecord(DebtDue d) {
    final found = debts.where((x) => x.id == d.record.id);
    if (found.isNotEmpty) _openDetail(found.first);
  }

  /// Teks hitung mundur: hari ini / N hari lagi / terlewat.
  static String dueCountdown(int daysLeft) {
    if (daysLeft < 0) {
      return tr('due_overdue').replaceFirst('{n}', '${-daysLeft}');
    }
    if (daysLeft == 0) return tr('due_today');
    return tr('due_in_days').replaceFirst('{n}', '$daysLeft');
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

/// Seksi segera jatuh tempo (deadline ≤7 hari, urut terdekat).
class _UpcomingCard extends StatelessWidget {
  final List<DebtDue> dues;
  final ValueChanged<DebtDue> onTap;

  const _UpcomingCard({required this.dues, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('due_upcoming'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: SsrSpace.sm),
          for (final d in dues)
            InkWell(
              onTap: () => onTap(d),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.record.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${DebtsScreenState.dueCountdown(d.daysLeft)} · '
                      '${amt(d.record.remaining())}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: d.daysLeft < 0
                            ? Theme.of(context).colorScheme.error
                            : null,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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
    final dueLeft = debt.dueDate == null
        ? null
        : daysUntilDue(debt.dueDate, DateTime.now());
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
        if (dueLeft != null)
          Text(
            '${tr('due_deadline')}: ${debt.dueDate} · '
            '${DebtsScreenState.dueCountdown(dueLeft)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
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
  DateTime? due;
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

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: due ?? date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && mounted) setState(() => due = picked);
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
        dueDate: due == null ? null : _ymd(due!),
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
            InkWell(
              onTap: _pickDue,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: tr('due_deadline'),
                  suffixIcon: due == null
                      ? null
                      : IconButton(
                          icon: const DuoIcon(AppIcons.close),
                          tooltip: tr('clear'),
                          onPressed: () => setState(() => due = null),
                        ),
                ),
                child: Text(
                  due == null ? tr('due_no_deadline') : _ymd(due!),
                ),
              ),
            ),
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
