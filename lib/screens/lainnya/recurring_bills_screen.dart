import 'package:flutter/material.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/services/recurring_bills.dart';
import 'package:ssr_space/services/wallet_service.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/category_chips.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/skeletons.dart';
import 'package:ssr_space/widgets/state_views.dart';

/// Daftar tagihan rutin (P2): kos, langganan, cicilan sebagai saran
/// sekali ketuk di Beranda. Tanpa migration, simpan di prefs.
class RecurringBillsScreen extends StatefulWidget {
  const RecurringBillsScreen({super.key});

  @override
  State<RecurringBillsScreen> createState() => RecurringBillsScreenState();
}

class RecurringBillsScreenState extends State<RecurringBillsScreen> {
  List<RecurringBill> bills = [];
  List<Wallet> wallets = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final orgId = await activeOrgId();
    final loaded = await loadBills();
    var ws = <Wallet>[];
    if (orgId.isNotEmpty) {
      try {
        ws = await WalletService().list(orgId);
      } catch (_) {}
    }
    final fixed = markWalletGone(loaded, {for (final w in ws) w.id});
    final changed = [
      for (var i = 0; i < loaded.length; i++)
        if (loaded[i].active != fixed[i].active) loaded[i],
    ];
    if (changed.isNotEmpty) await saveBills(fixed);
    if (!mounted) return;
    setState(() {
      bills = fixed;
      wallets = ws;
      loading = false;
    });
    if (changed.isNotEmpty && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('rb_wallet_gone'))));
    }
  }

  String _walletName(String id) {
    for (final w in wallets) {
      if (w.id == id) return w.name;
    }
    return '-';
  }

  Future<void> _save(RecurringBill bill) async {
    final next = [...bills];
    final i = next.indexWhere((b) => b.id == bill.id);
    if (i >= 0) {
      next[i] = bill;
    } else {
      if (next.length >= maxBills) return;
      next.add(bill);
    }
    await saveBills(next);
    if (mounted) setState(() => bills = next);
  }

  Future<void> _toggle(RecurringBill bill, bool v) async {
    if (!v || wallets.any((w) => w.id == bill.walletId)) {
      await _save(bill.copyWith(active: v));
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('rb_wallet_gone'))));
    }
  }

  Future<void> _delete(RecurringBill bill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('rb_del_t')),
        content: Text(tr('rb_del_s')),
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
    if (ok != true) return;
    final next = bills.where((b) => b.id != bill.id).toList();
    await saveBills(next);
    if (mounted) setState(() => bills = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('rb_title'))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(null),
        child: const Icon(Icons.add),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (loading) {
      return const TxListSkeleton();
    }
    if (bills.isEmpty) {
      return EmptyView(
        icon: AppIcons.bills,
        title: tr('rb_empty_t'),
        subtitle: tr('rb_empty_s'),
        actionLabel: tr('rb_add'),
        onAction: () => _openEditor(null),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(SsrSpace.lg),
      itemCount: bills.length,
      itemBuilder: (_, i) => _billTile(bills[i]),
    );
  }

  Widget _billTile(RecurringBill bill) {
    final period = bill.period == 'weekly' ? tr('rb_weekly') : tr('rb_monthly');
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _openEditor(bill),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${amt(bill.amount)} · $period · ${bill.nextDue} · ${_walletName(bill.walletId)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Switch(value: bill.active, onChanged: (v) => _toggle(bill, v)),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(bill),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(RecurringBill? bill) async {
    final saved = await showModalBottomSheet<RecurringBill>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BillEditor(bill: bill, wallets: wallets),
    );
    if (saved != null) await _save(saved);
  }
}

/// Form tambah/ubah tagihan dalam bottom sheet.
class _BillEditor extends StatefulWidget {
  final RecurringBill? bill;
  final List<Wallet> wallets;

  const _BillEditor({required this.bill, required this.wallets});

  @override
  State<_BillEditor> createState() => _BillEditorState();
}

class _BillEditorState extends State<_BillEditor> {
  late final TextEditingController labelC;
  late final TextEditingController amountC;
  late final TextEditingController catC;
  late final TextEditingController anchorC;
  String period = 'monthly';
  String? walletId;
  String? err;

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    labelC = TextEditingController(text: b?.label ?? '');
    amountC = TextEditingController(
      text: b == null ? '' : b.amount.toStringAsFixed(0),
    );
    catC = TextEditingController(text: b?.category ?? '');
    period = b?.period ?? 'monthly';
    anchorC = TextEditingController(
      text: '${b?.anchorDay ?? DateTime.now().day}',
    );
    walletId = b?.walletId ??
        (widget.wallets.isNotEmpty ? widget.wallets.first.id : null);
  }

  @override
  void dispose() {
    labelC.dispose();
    amountC.dispose();
    catC.dispose();
    anchorC.dispose();
    super.dispose();
  }

  void _submit() {
    final label = labelC.text.trim();
    final amount = double.tryParse(amountC.text.trim());
    final anchor = int.tryParse(anchorC.text.trim());
    if (label.isEmpty || amount == null || amount <= 0) {
      setState(() => err = tr('tx_err_amount'));
      return;
    }
    if (walletId == null || walletId!.isEmpty) {
      setState(() => err = tr('st_need_wallet'));
      return;
    }
    final day = (anchor ?? DateTime.now().day).clamp(1, 31);
    final now = DateTime.now();
    final due = period == 'weekly'
        ? DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 7))
        : monthlyDue(
            now.month == 12 ? now.year + 1 : now.year,
            now.month == 12 ? 1 : now.month + 1,
            day,
          );
    final bill = (widget.bill ??
            RecurringBill(
              id: newBillId(),
              label: label,
              amount: amount,
              category: catC.text.trim(),
              walletId: walletId!,
              period: period,
              anchorDay: period == 'weekly' ? now.weekday : day,
              nextDue: '',
              active: true,
            ))
        .copyWith(
      label: label,
      amount: amount,
      category: catC.text.trim(),
      walletId: walletId!,
      period: period,
      anchorDay: period == 'weekly' ? now.weekday : day,
      nextDue: widget.bill?.nextDue ??
          '${due.year.toString().padLeft(4, '0')}-'
              '${due.month.toString().padLeft(2, '0')}-'
              '${due.day.toString().padLeft(2, '0')}',
    );
    Navigator.pop(context, bill);
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
              widget.bill == null ? tr('rb_add') : widget.bill!.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: SsrSpace.md),
            TextField(
              controller: labelC,
              decoration: InputDecoration(labelText: tr('rb_label')),
            ),
            const SizedBox(height: SsrSpace.sm),
            TextField(
              controller: amountC,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('rb_amount')),
            ),
            const SizedBox(height: SsrSpace.sm),
            CategoryChips(controller: catC),
            const SizedBox(height: SsrSpace.sm),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'weekly',
                  label: Text(tr('rb_weekly')),
                ),
                ButtonSegment(
                  value: 'monthly',
                  label: Text(tr('rb_monthly')),
                ),
              ],
              selected: {period},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => period = s.first),
            ),
            if (period == 'monthly') ...[
              const SizedBox(height: SsrSpace.sm),
              TextField(
                controller: anchorC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('rb_anchor')),
              ),
            ],
            const SizedBox(height: SsrSpace.sm),
            DropdownButtonFormField<String>(
              initialValue: walletId,
              items: [
                for (final w in widget.wallets)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => walletId = v),
              decoration: InputDecoration(labelText: tr('tx_f_wallet')),
            ),
            if (err != null) ...[
              const SizedBox(height: SsrSpace.sm),
              Text(err!, style: const TextStyle(color: SsrColors.danger)),
            ],
            const SizedBox(height: SsrSpace.md),
            FilledButton(onPressed: _submit, child: Text(tr('save'))),
          ],
        ),
      ),
    );
  }
}
