import 'package:ssr_space/core/saas/month.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/core/saas/transaction_service.dart';

double budgetProgress(double spent, double limit) {
  if (limit <= 0) return 0;
  final p = spent / limit;
  return p > 1 ? 1 : p;
}

class Budget {
  final String category;
  final double limit;
  final double spent;
  Budget({required this.category, required this.limit, required this.spent});
}

Future<List<Budget>> fetchBudgets(String orgId) async {
  final c = SupabaseConfig.client;
  final rows = await c.from('budgets').select().eq('org_id', orgId).eq('month', currentMonth());
  final txs = await TransactionService().list(orgId);
  final spent = <String, double>{};
  for (final t in txs) {
    if (t.type == 'out' && (t.date ?? '').startsWith(currentMonth())) {
      final k = (t.category?.isNotEmpty ?? false) ? t.category! : 'Lainnya';
      spent[k] = (spent[k] ?? 0) + t.amount;
    }
  }
  return [
    for (final r in List<Map<String, dynamic>>.from(rows))
      Budget(
        category: (r['category'] ?? '').toString(),
        limit: (r['limit_amount'] as num).toDouble(),
        spent: spent[(r['category'] ?? '').toString()] ?? 0,
      ),
  ];
}

Future<void> setBudget(String orgId, String category, double limit) async {
  await SupabaseConfig.client.from('budgets').upsert(
    {'org_id': orgId, 'category': category, 'month': currentMonth(), 'limit_amount': limit},
    onConflict: 'org_id,category,month',
  );
}
