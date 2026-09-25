import 'package:flutter/material.dart';
import 'package:ssr_space/utils/org_prefs.dart';
import 'package:ssr_space/utils/mask.dart';
import 'package:ssr_space/services/budget_service.dart';
import 'package:ssr_space/services/month.dart';
import 'package:ssr_space/theme/app_theme.dart';
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

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final orgId = await activeOrgId();
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
      await setBudget(await activeOrgId(), cat, limit);
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
          for (final b in items) _BudgetCard(budget: b),
          const SizedBox(height: SsrSpace.md),
          _BudgetForm(
            catC: catC,
            limitC: limitC,
            catFocus: catFocus,
            formErr: formErr,
            saving: saving,
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

/// Kartu satu kategori: nama + chip (persen / lebih batas), angka
/// "terpakai dari batas", dan bar progres.
class _BudgetCard extends StatelessWidget {
  final Budget budget;

  const _BudgetCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final b = budget;
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
            '${amt(b.spent)} dari ${amt(b.limit)}',
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

/// Kartu form "Batas baru": kategori + nominal batas + tombol simpan.
class _BudgetForm extends StatelessWidget {
  final TextEditingController catC;
  final TextEditingController limitC;
  final FocusNode catFocus;
  final String? formErr;
  final bool saving;
  final VoidCallback onSave;

  const _BudgetForm({
    required this.catC,
    required this.limitC,
    required this.catFocus,
    required this.formErr,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Batas baru', style: Theme.of(context).textTheme.titleMedium),
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
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
