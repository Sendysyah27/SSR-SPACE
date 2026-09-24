import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/saas/budget_service.dart';
import 'package:ssr_space/core/saas/month.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';
import 'package:ssr_space/widgets/state_views.dart';
import 'package:ssr_space/widgets/status_chip.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});
  @override
  State<BudgetsScreen> createState() => BudgetsScreenState();
}

class BudgetsScreenState extends State<BudgetsScreen> {
  List<Budget> items = [];
  bool loading = true;
  bool saving = false;
  String? err;
  String? formErr;
  final catC = TextEditingController();
  final limitC = TextEditingController();
  final catFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    catC.dispose();
    limitC.dispose();
    catFocus.dispose();
    super.dispose();
  }

  Future<String> _orgId() async =>
      (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await _orgId();
      if (orgId.isEmpty) {
        setState(() => loading = false);
        return;
      }
      final b = await fetchBudgets(orgId);
      if (!mounted) return;
      setState(() {
        items = b;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = 'Gagal memuat budget. Periksa koneksi.';
      });
    }
  }

  Future<void> _save() async {
    final cat = catC.text.trim();
    final limit = double.tryParse(limitC.text);
    if (cat.isEmpty) {
      setState(() => formErr = 'Isi nama kategori dulu.');
      return;
    }
    if (limit == null || limit <= 0) {
      setState(() => formErr = 'Batas harus angka lebih dari 0.');
      return;
    }
    setState(() {
      formErr = null;
      saving = true;
    });
    try {
      await setBudget(await _orgId(), cat, limit);
      catC.clear();
      limitC.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Budget disimpan.')));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => formErr = 'Gagal menyimpan. Periksa koneksi.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _focusForm() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      catFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Budget ${currentMonth()}')),
        body: const LoadingView(label: 'Memuat budget...'),
      );
    }
    if (err != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Budget ${currentMonth()}')),
        body: ErrorView(message: err!, onRetry: _load),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Budget ${currentMonth()}')),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          if (items.isEmpty)
            EmptyView(
              icon: Icons.savings_outlined,
              title: 'Belum ada budget bulan ini.',
              subtitle: 'Pasang batas pertama lewat form di bawah.',
              actionLabel: 'Isi budget',
              onAction: _focusForm,
            ),
          for (final b in items) _budgetCard(b),
          const SizedBox(height: SsrSpace.md),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batas baru',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: SsrSpace.md),
                TextField(
                  controller: catC,
                  focusNode: catFocus,
                  decoration: const InputDecoration(
                    labelText: 'Kategori (misal Makan)',
                  ),
                ),
                const SizedBox(height: SsrSpace.md),
                TextField(
                  controller: limitC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Batas (Rp)',
                    prefixText: 'Rp ',
                  ),
                ),
                if (formErr != null) ...[
                  const SizedBox(height: SsrSpace.sm),
                  Text(
                    formErr!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: SsrColors.danger),
                  ),
                ],
                const SizedBox(height: SsrSpace.lg),
                PrimaryButton(
                  label: 'Simpan budget',
                  loading: saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetCard(Budget b) {
    final over = b.spent > b.limit;
    final progress = budgetProgress(b.spent, b.limit);
    final pct = b.limit > 0 ? (b.spent / b.limit * 100).round() : 0;
    return SectionCard(
      margin: const EdgeInsets.only(bottom: SsrSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b.category,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (over)
                const StatusChip(label: 'Lebih batas', tone: StatusTone.danger)
              else
                StatusChip(label: '$pct%', tone: StatusTone.accent),
            ],
          ),
          const SizedBox(height: SsrSpace.xs),
          Text(
            '${rp(b.spent)} dari ${rp(b.limit)}',
            style: SsrTheme.money.copyWith(fontSize: 14),
          ),
          const SizedBox(height: SsrSpace.md),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: SsrMotion.base,
            curve: SsrMotion.curve,
            builder: (_, value, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                color: over ? SsrColors.danger : SsrColors.accent,
                backgroundColor: SsrColors.accentSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
