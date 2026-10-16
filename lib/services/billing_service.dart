import 'package:ssr_space/services/supabase_config.dart';

const proPrice = 25000.0;

Future<String> currentPlan(String orgId) async {
  final row = await SupabaseConfig.client.from('organizations').select('plan').eq('id', orgId).single();
  return ((row as Map)['plan'] ?? 'free').toString();
}

/// Status paket dari server (RPC plan_status, migration_20).
/// Sukses → {plan, source, expiresAt, stale:false}.
/// Gagal (RPC belum ada / offline) → fallback currentPlan() lama + stale:true.
/// Tak pernah rethrow — pemanggil selalu dapat jawaban.
Future<Map<String, dynamic>> planStatus(String orgId) async {
  try {
    final res = await SupabaseConfig.client.rpc(
      'plan_status',
      params: {'p_org_id': orgId},
    );
    final m = Map<String, dynamic>.from(res as Map);
    return <String, dynamic>{
      'plan': (m['plan'] ?? 'free').toString(),
      'source': m['source']?.toString(),
      'expiresAt': m['expires_at']?.toString(),
      'stale': false,
    };
  } catch (_) {
    String plan = 'free';
    try {
      plan = await currentPlan(orgId);
    } catch (_) {
      plan = 'free';
    }
    return <String, dynamic>{
      'plan': plan,
      'source': null,
      'expiresAt': null,
      'stale': true,
    };
  }
}
