import 'package:ssr_space/core/saas/supabase_config.dart';

const proPrice = 25000.0;

Future<String> currentPlan(String orgId) async {
  final row = await SupabaseConfig.client.from('organizations').select('plan').eq('id', orgId).single();
  return ((row as Map)['plan'] ?? 'free').toString();
}

Future<void> requestUpgrade(String orgId, String plan, double amount) async {
  await SupabaseConfig.client.from('subscriptions').insert({
    'org_id': orgId,
    'plan': plan,
    'status': 'pending',
    'amount': amount,
  });
}
