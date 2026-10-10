import 'package:ssr_space/services/supabase_config.dart';

const proPrice = 25000.0;

Future<String> currentPlan(String orgId) async {
  final row = await SupabaseConfig.client.from('organizations').select('plan').eq('id', orgId).single();
  return ((row as Map)['plan'] ?? 'free').toString();
}
