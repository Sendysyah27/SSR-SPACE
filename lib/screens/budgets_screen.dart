import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssr_space/core/saas/budget_service.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});
  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  List<Budget> items = [];
  final catC = TextEditingController();
  final limitC = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<String> _orgId() async => (await SharedPreferences.getInstance()).getString('active_org_id') ?? '';

  Future<void> _load() async {
    final orgId = await _orgId();
    if (orgId.isEmpty) return;
    final b = await fetchBudgets(orgId);
    if (!mounted) return;
    setState(() => items = b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Budget ${currentMonth()}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final b in items)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${b.category}: ${b.spent.toStringAsFixed(0)} / ${b.limit.toStringAsFixed(0)}'),
            LinearProgressIndicator(
              value: budgetProgress(b.spent, b.limit),
              color: budgetProgress(b.spent, b.limit) >= 1 ? Colors.red : Colors.teal,
            ),
            const SizedBox(height: 12),
          ]),
        const Divider(),
        TextField(controller: catC, decoration: const InputDecoration(labelText: 'Kategori')),
        TextField(controller: limitC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Batas')),
        ElevatedButton(
          onPressed: () async {
            await setBudget(await _orgId(), catC.text.trim(), double.parse(limitC.text));
            catC.clear(); limitC.clear();
            await _load();
          },
          child: const Text('Simpan budget'),
        ),
      ]),
    );
  }
}
