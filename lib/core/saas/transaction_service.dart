import 'package:ssr_space/core/saas/month.dart';
import 'package:ssr_space/core/saas/supabase_config.dart';
import 'package:ssr_space/models/transaction.dart';

class TransactionService {
  Future<List<SaasTransaction>> list(String orgId) async {
    final rows = await SupabaseConfig.client
        .from('transactions')
        .select()
        .eq('org_id', orgId)
        .order('date', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows).map(SaasTransaction.fromMap).toList();
  }

  Future<List<SaasTransaction>> listMonth(String orgId, String month) async {
    final rows = await SupabaseConfig.client
        .from('transactions')
        .select()
        .eq('org_id', orgId)
        .gte('date', monthStart(month))
        .lt('date', monthEnd(month))
        .order('date', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows).map(SaasTransaction.fromMap).toList();
  }

  Future<String> mintCode(String orgId) async {
    final res = await SupabaseConfig.client.rpc('mint_tx_code', params: {'p_org_id': orgId});
    return res.toString();
  }

  Future<void> add({
    required String orgId,
    required String type,
    required double amount,
    String? walletId,
    String? toWalletId,
    String? category,
    String? note,
    String? code,
  }) async {
    assert(amount > 0);
    await SupabaseConfig.client.from('transactions').insert({
      'org_id': orgId,
      'type': type,
      'amount': amount,
      'wallet_id': walletId,
      'to_wallet_id': toWalletId,
      'category': category,
      'note': note,
      'code': code,
      'created_by': SupabaseConfig.client.auth.currentUser?.id,
    });
  }
}
