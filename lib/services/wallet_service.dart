import 'package:ssr_space/services/supabase_config.dart';
import 'package:ssr_space/models/wallet.dart';
import 'package:ssr_space/models/wallet_balance.dart';

class WalletService {
  Future<List<Wallet>> list(String orgId) async {
    final rows = await SupabaseConfig.client.from('wallets').select().eq('org_id', orgId).order('created_at');
    return List<Map<String, dynamic>>.from(rows).map(Wallet.fromMap).toList();
  }

  Future<String> create(String orgId, String name, String type) async {
    final row = await SupabaseConfig.client
        .from('wallets')
        .insert({'org_id': orgId, 'name': name, 'type': type})
        .select('id')
        .single();
    return row['id'].toString();
  }

  Future<void> rename(String id, String orgId, String name) async {
    await SupabaseConfig.client
        .from('wallets')
        .update({'name': name})
        .eq('id', id)
        .eq('org_id', orgId);
  }

  Future<void> changeType(String id, String orgId, String type) async {
    await SupabaseConfig.client
        .from('wallets')
        .update({'type': type})
        .eq('id', id)
        .eq('org_id', orgId);
  }

  Future<bool> hasTransactions(String orgId, String walletId) async {
    final rows = await SupabaseConfig.client
        .from('transactions')
        .select('id')
        .eq('org_id', orgId)
        .or('wallet_id.eq.$walletId,to_wallet_id.eq.$walletId')
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<void> deleteWallet(String id, String orgId) async {
    await SupabaseConfig.client
        .from('wallets')
        .delete()
        .eq('id', id)
        .eq('org_id', orgId);
  }

  Future<List<WalletBalance>> balances(String orgId) async {
    final rows = await SupabaseConfig.client
        .from('wallet_balance')
        .select()
        .eq('org_id', orgId);
    return List<Map<String, dynamic>>.from(rows)
        .map(WalletBalance.fromMap)
        .toList();
  }
}
