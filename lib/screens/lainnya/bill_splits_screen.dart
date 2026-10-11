import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/models/transaction.dart';
import 'package:ssr_space/services/bill_split.dart';
import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/services/transaction_service.dart';
import 'package:ssr_space/services/workspace_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';
import 'package:ssr_space/widgets/tx_type_selector.dart';

/// Kunci prefs daftar patungan (maks [maxSplits]).
const _kSplits = 'bill_splits';

Future<List<SplitBill>> loadSplits() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kSplits);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    final out = <SplitBill>[];
    for (final e in list) {
      final b = SplitBill.tryParse(e);
      if (b != null) out.add(b);
      if (out.length >= maxSplits) break;
    }
    return out;
  } catch (_) {
    return [];
  }
}

Future<void> saveSplits(List<SplitBill> splits) async {
  final capped = splits.take(maxSplits).toList();
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _kSplits,
    jsonEncode([for (final s in capped) s.toJson()]),
  );
}

/// Daftar patungan workspace aktif (simpan lokal HP, lunas = status).
class BillSplitsScreen extends StatefulWidget {
  const BillSplitsScreen({super.key});

  @override
  State<BillSplitsScreen> createState() => BillSplitsScreenState();
}

class BillSplitsScreenState extends State<BillSplitsScreen> {
  bool loading = true;
  bool loadFailed = false;
  bool noOrg = false;
  List<SplitBill> splits = [];
  String orgId = '';
  String myId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadFailed = false;
      noOrg = false;
    });
    final org = await activeOrgId();
    if (org.isEmpty) {
      if (!mounted) return;
      setState(() {
        loading = false;
        noOrg = true;
      });
      return;
    }
    List<SplitBill> loaded;
    try {
      loaded = await loadSplits();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadFailed = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      loading = false;
      splits = loaded;
      orgId = org;
      myId = SupabaseConfig.client.auth.currentUser?.id ?? '';
    });
  }

  Future<void> _update(SplitBill next) async {
    final list = [for (final s in splits) s.id == next.id ? next : s];
    await saveSplits(list);
    if (mounted) setState(() => splits = list);
  }

  Future<void> _remove(String id) async {
    final list = splits.where((s) => s.id != id).toList();
    await saveSplits(list);
    if (mounted) setState(() => splits = list);
  }

  Future<void> _create() async {
    final made = await showModalBottomSheet<SplitBill>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SplitWizard(orgId: orgId, myId: myId),
    );
    if (made == null) return;
    if (splits.length >= maxSplits) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('bs_full'))));
      return;
    }
    final list = [...splits, made];
    await saveSplits(list);
    if (!mounted) return;
    setState(() => splits = list);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('bs_saved'))));
  }

  Future<void> _openDetail(SplitBill s) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SplitDetailSheet(
        split: s,
        myId: myId,
        onChanged: _update,
        onDelete: () => _remove(s.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('bs_title'))),
      floatingActionButton: (loading || noOrg || loadFailed)
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
    if (noOrg) {
      return EmptyView(
        icon: AppIcons.workspace,
        title: tr('tx_no_org_t'),
        subtitle: tr('tx_no_org_s'),
        actionLabel: tr('reload'),
        onAction: _load,
      );
    }
    if (loadFailed) {
      return ErrorView(message: tr('tx_err_load'), onRetry: _load);
    }
    if (splits.isEmpty) {
      return EmptyView(
        icon: AppIcons.transfer,
        title: tr('bs_empty_t'),
        subtitle: tr('bs_empty_s'),
        actionLabel: tr('bs_new'),
        onAction: _create,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(SsrSpace.lg),
      itemCount: splits.length,
      itemBuilder: (_, i) =>
          _SplitTile(split: splits[i], myId: myId, onTap: _openDetail),
    );
  }
}

/// Satu baris patungan: judul, total, progres lunas.
class _SplitTile extends StatelessWidget {
  final SplitBill split;
  final String myId;
  final ValueChanged<SplitBill> onTap;

  const _SplitTile({
    required this.split,
    required this.myId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final done = isFullySettled(split);
    final progress = tr('bs_paid')
        .replaceFirst('{n}', '${settledCount(split)}')
        .replaceFirst('{m}', '${shareCount(split) - 1}');
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: InkWell(
        onTap: () => onTap(split),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    split.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${amt(split.total)} · ${done ? tr('bs_done') : progress}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            StatusChip(
              label: done ? tr('bs_done') : progress,
              tone: done ? StatusTone.accent : StatusTone.neutral,
            ),
          ],
        ),
      ),
    );
  }
}

/// Isi detail patungan: daftar utang + tandai lunas + hapus.
class _SplitDetailSheet extends StatefulWidget {
  final SplitBill split;
  final String myId;
  final ValueChanged<SplitBill> onChanged;
  final VoidCallback onDelete;

  const _SplitDetailSheet({
    required this.split,
    required this.myId,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_SplitDetailSheet> createState() => _SplitDetailSheetState();
}

class _SplitDetailSheetState extends State<_SplitDetailSheet> {
  late SplitBill bill;

  @override
  void initState() {
    super.initState();
    bill = widget.split;
  }

  String _name(String userId) => shortMemberLabel(
    userId,
    userId == widget.myId,
    meSuffix: tr('bs_me'),
  );

  void _settle(String userId, bool done) {
    final next = {...bill.settled};
    if (done) {
      next.add(userId);
    } else {
      next.remove(userId);
    }
    final updated = bill.copyWith(settled: next);
    setState(() => bill = updated);
    widget.onChanged(updated);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('bs_del_t')),
        content: Text(tr('bs_del_s')),
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
    final debts = debtsOf(bill);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHead(context),
            const SizedBox(height: SsrSpace.sm),
            if (debts.isEmpty)
              _doneRow(context)
            else
              for (final d in debts) _debtRow(context, d),
            const SizedBox(height: SsrSpace.sm),
            _settledRows(context),
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

  Widget _sheetHead(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            bill.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(
          amt(bill.total),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _doneRow(BuildContext context) {
    return StatusChip(label: tr('bs_done'), tone: StatusTone.accent);
  }

  Widget _debtRow(BuildContext context, BillDebt d) {
    final text = tr('bs_owes')
        .replaceFirst('{a}', _name(d.from))
        .replaceFirst('{m}', amt(d.amount))
        .replaceFirst('{b}', _name(d.to));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          TextButton(
            onPressed: () => _settle(d.from, true),
            child: Text(tr('bs_settle')),
          ),
        ],
      ),
    );
  }

  Widget _settledRows(BuildContext context) {
    final rows = bill.shares
        .where(
          (s) => s.userId != bill.payerId && bill.settled.contains(s.userId),
        )
        .toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_name(s.userId)} · ${tr('bs_done')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => _settle(s.userId, false),
                  child: Text(tr('bs_unsettle')),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Wizard buat patungan: 1 transaksi → 2 peserta → 3 porsi.
class _SplitWizard extends StatefulWidget {
  final String orgId;
  final String myId;

  const _SplitWizard({required this.orgId, required this.myId});

  @override
  State<_SplitWizard> createState() => _SplitWizardState();
}

class _SplitWizardState extends State<_SplitWizard> {
  int step = 0;
  final titleC = TextEditingController();
  List<SaasTransaction> txs = [];
  bool txLoading = true;
  SaasTransaction? picked;
  List<OrgMember> members = [];
  bool memberLoading = true;
  Set<String> selected = {};
  String payer = '';
  String mode = 'equal';
  final Map<String, TextEditingController> amountCs = {};
  String? err;

  @override
  void initState() {
    super.initState();
    payer = widget.myId;
    selected = {widget.myId};
    _loadTxs();
    _loadMembers();
  }

  @override
  void dispose() {
    titleC.dispose();
    for (final c in amountCs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTxs() async {
    try {
      final all = await TransactionService().list(widget.orgId);
      if (!mounted) return;
      setState(() {
        txs = all.where((t) => t.type == 'out' && t.amount > 0).toList();
        txLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => txLoading = false);
    }
  }

  Future<void> _loadMembers() async {
    try {
      final rows = await WorkspaceService().members(widget.orgId);
      if (!mounted) return;
      setState(() {
        members = rows;
        memberLoading = false;
        if (rows.isNotEmpty && !selected.contains(payer)) {
          payer = rows.first.userId;
          selected = {payer};
        }
      });
    } catch (_) {
      if (mounted) setState(() => memberLoading = false);
    }
  }

  String _txLabel(SaasTransaction t) {
    final c = (t.category ?? '').trim();
    if (c.isNotEmpty) return c;
    final n = (t.note ?? '').trim();
    if (n.isNotEmpty) return n;
    return t.date ?? '-';
  }

  String _name(String userId) => shortMemberLabel(
    userId,
    userId == widget.myId,
    meSuffix: tr('bs_me'),
  );

  List<String> get _ids => [
    for (final m in members)
      if (selected.contains(m.userId)) m.userId,
  ];

  void _pickTx(SaasTransaction t) {
    setState(() {
      picked = t;
      if (titleC.text.trim().isEmpty) titleC.text = _txLabel(t);
    });
  }

  void _toggleMember(String userId, bool v) {
    final next = {...selected};
    if (v) {
      next.add(userId);
    } else {
      next.remove(userId);
    }
    setState(() {
      selected = next;
      err = null;
      if (!next.contains(payer) && next.isNotEmpty) payer = next.first;
    });
  }

  void _nextFromMembers() {
    if (_ids.length < 2) {
      setState(() => err = tr('bs_need_two'));
      return;
    }
    setState(() {
      err = null;
      step = 2;
    });
  }

  void _save() {
    final tx = picked;
    if (tx == null) {
      setState(() => err = tr('bs_pick_tx'));
      return;
    }
    var title = titleC.text.trim();
    if (title.isEmpty) title = _txLabel(tx);
    final ids = _ids;
    Map<String, double> shares;
    if (mode == 'equal') {
      shares = equalShares(tx.amount, ids);
    } else {
      final parsed = <String, double>{};
      for (final id in ids) {
        final v = double.tryParse(
          (amountCs[id]?.text ?? '').trim().replaceAll(',', '.'),
        );
        if (v == null) {
          setState(() => err = tr('bs_err_number'));
          return;
        }
        parsed[id] = v;
      }
      final problem = validateCustomShares(tx.amount, parsed);
      if (problem != null) {
        setState(
          () => err = problem == 'empty'
              ? tr('bs_need_two')
              : tr('bs_err_mismatch'),
        );
        return;
      }
      shares = parsed;
    }
    Navigator.pop(
      context,
      SplitBill(
        id: newSplitId(),
        title: title,
        txId: tx.id,
        total: tx.amount,
        payerId: payer,
        shares: [
          for (final id in ids) SplitShare(userId: id, amount: shares[id] ?? 0),
        ],
        settled: {},
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
              '${tr('bs_new')} · ${step + 1}/3',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: SsrSpace.md),
            if (step == 0) _txStep() else if (step == 1) _memberStep(),
            if (step == 2) _shareStep(),
            if (err != null) _errText(context),
            const SizedBox(height: SsrSpace.md),
            _navRow(),
          ],
        ),
      ),
    );
  }

  Widget _errText(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: SsrSpace.sm),
      child: Text(
        err!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _navRow() {
    return Row(
      children: [
        if (step > 0)
          TextButton(
            onPressed: () => setState(() {
              err = null;
              step--;
            }),
            child: Text(tr('back')),
          ),
        const Spacer(),
        if (step < 2)
          FilledButton(
            onPressed: step == 0
                ? (picked == null
                      ? null
                      : () => setState(() {
                          err = null;
                          step = 1;
                        }))
                : _nextFromMembers,
            child: Text(tr('bs_next')),
          )
        else
          FilledButton(onPressed: _save, child: Text(tr('bs_save'))),
      ],
    );
  }

  Widget _txStep() {
    if (txLoading) return const TxListSkeleton();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: titleC,
          decoration: InputDecoration(labelText: tr('bs_tx_title')),
        ),
        const SizedBox(height: SsrSpace.sm),
        Text(tr('bs_pick_tx'), style: Theme.of(context).textTheme.bodySmall),
        if (txs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: SsrSpace.md),
            child: Text(
              tr('tx_empty_t'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          for (final t in txs.take(30)) _txRow(t),
      ],
    );
  }

  Widget _txRow(SaasTransaction t) {
    final isPicked = picked?.id == t.id;
    return SectionCard(
      margin: const EdgeInsets.only(top: SsrSpace.sm),
      child: InkWell(
        onTap: () => _pickTx(t),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _txLabel(t),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    t.date ?? '-',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              amt(t.amount),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (isPicked) ...[
              const SizedBox(width: SsrSpace.sm),
              const DuoIcon(AppIcons.check),
            ],
          ],
        ),
      ),
    );
  }

  Widget _memberStep() {
    if (memberLoading) return const TxListSkeleton();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr('bs_members'), style: Theme.of(context).textTheme.bodySmall),
        for (final m in members)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_name(m.userId)),
            value: selected.contains(m.userId),
            onChanged: (v) => _toggleMember(m.userId, v ?? false),
          ),
        const SizedBox(height: SsrSpace.sm),
        DropdownButtonFormField<String>(
          initialValue: _ids.contains(payer) ? payer : null,
          items: [
            for (final id in _ids)
              DropdownMenuItem(value: id, child: Text(_name(id))),
          ],
          onChanged: (v) => setState(() {
            if (v != null) payer = v;
          }),
          decoration: InputDecoration(labelText: tr('bs_payer')),
        ),
      ],
    );
  }

  Widget _shareStep() {
    final tx = picked;
    if (tx == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${amt(tx.amount)} · ${_name(payer)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: SsrSpace.sm),
        SegmentedButton<String>(
          style: ssrSegmentedStyle(context),
          segments: [
            ButtonSegment(value: 'equal', label: Text(tr('bs_equal'))),
            ButtonSegment(value: 'custom', label: Text(tr('bs_custom'))),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() {
            mode = s.first;
            err = null;
          }),
        ),
        if (mode == 'equal') _equalPreview(tx.amount) else _customFields(),
      ],
    );
  }

  Widget _equalPreview(double total) {
    final m = equalShares(total, _ids);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: SsrSpace.sm),
        for (final id in _ids)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(_name(id))),
                Text(
                  amt(m[id] ?? 0),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _customFields() {
    for (final id in _ids) {
      amountCs.putIfAbsent(id, TextEditingController.new);
    }
    final stale = amountCs.keys.where((k) => !_ids.contains(k)).toList();
    for (final k in stale) {
      amountCs[k]?.dispose();
      amountCs.remove(k);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: SsrSpace.sm),
        for (final id in _ids)
          Padding(
            padding: const EdgeInsets.only(bottom: SsrSpace.sm),
            child: TextField(
              controller: amountCs[id],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _name(id)),
            ),
          ),
      ],
    );
  }
}
