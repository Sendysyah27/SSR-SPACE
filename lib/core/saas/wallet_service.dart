import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/models/wallet.dart';

class WalletService {
  Future<List<Wallet>> list(String orgId) async {
    final rows = await SupabaseConfig.client.from('wallets').select().eq('org_id', orgId).order('created_at');
    return List<Map<String, dynamic>>.from(rows).map(Wallet.fromMap).toList();
  }

  Future<void> create(String orgId, String name, String type) async {
    await SupabaseConfig.client.from('wallets').insert({'org_id': orgId, 'name': name, 'type': type});
  }
}
