import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/format/money.dart';
import 'package:ssr_space/core/saas/budget_service.dart';
import 'package:ssr_space/core/saas/month.dart';
import 'package:ssr_space/core/theme/app_theme.dart';
import 'package:ssr_space/widgets/state_views.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});
  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  List<Budget> items = [];
  bool loading = true;
  String? err;
  final catC = TextEditingController();
  final limitC = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<String> _orgId() async => (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';

  Future<void> _load() async {
    setState(() { loading = true; err = null; });
    try {
      final orgId = await _orgId();
      if (orgId.isEmpty) {
        setState(() => loading = false);
        return;
      }
      final b = await fetchBudgets(orgId);
      if (!mounted) return;
      setState(() { items = b; loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { loading = false; err = 'Gagal memuat budget. Periksa koneksi.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(appBar: AppBar(title: Text('Budget ${currentMonth()}')), body: const LoadingView(label: 'Memuat budget...'));
    }
    if (err != null) {
      return Scaffold(appBar: AppBar(title: Text('Budget ${currentMonth()}')), body: ErrorView(message: err!, onRetry: _load));
    }
    return Scaffold(
      appBar: AppBar(title: Text('Budget ${currentMonth()}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Belum ada budget bulan ini. Pasang batas pertama di bawah.', style: Theme.of(context).textTheme.bodyMedium),
          ),
        for (final b in items) ...[
          Text('${b.category}', style: Theme.of(context).textTheme.titleMedium),
          Text('${rp(b.spent)} dari ${rp(b.limit)}', style: SsrTheme.money),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: budgetProgress(b.spent, b.limit),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: budgetProgress(b.spent, b.limit) >= 1 ? SsrColors.danger : SsrColors.accent,
            backgroundColor: SsrColors.accent.withOpacity(0.15),
          ),
          const SizedBox(height: 14),
        ],
        const Divider(),
        Text('Batas baru', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(controller: catC, decoration: const InputDecoration(labelText: 'Kategori (misal Makan)')),
        const SizedBox(height: 8),
        TextField(controller: limitC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Batas (Rp)', prefixText: 'Rp ')),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            final limit = double.tryParse(limitC.text);
            if (catC.text.trim().isEmpty || limit == null || limit <= 0) return;
            await setBudget(await _orgId(), catC.text.trim(), limit);
            catC.clear(); limitC.clear();
            await _load();
          },
          child: const Text('Simpan budget'),
        ),
      ]),
    );
  }
}
