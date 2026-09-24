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
        .order('created_at', ascending: false)
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
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows).map(SaasTransaction.fromMap).toList();
  }

  Future<String> mintCode(String orgId) async {
    final res = await SupabaseConfig.client.rpc('mint_tx_code', params: {'p_org_id': orgId});
    return res.toString();
  }

  /// Insert dulu (code nullable), baru mint + update — supaya nomor TX tidak
  /// terbakar bila insert gagal (duplikat hash, RLS, dll).
  Future<String?> add({
    required String orgId,
    required String type,
    required double amount,
    String? walletId,
    String? toWalletId,
    String? category,
    String? note,
    String? code,
    String? date,
    String? sourcePackage,
    String? sourceHash,
  }) async {
    assert(amount > 0);
    final row = await SupabaseConfig.client
        .from('transactions')
        .insert({
          'org_id': orgId,
          'type': type,
          'amount': amount,
          'wallet_id': walletId,
          'to_wallet_id': toWalletId,
          'category': category,
          'note': note,
          'code': code,
          'date': date,
          'source_package': sourcePackage,
          'source_hash': sourceHash,
          'created_by': SupabaseConfig.client.auth.currentUser?.id,
        })
        .select('id')
        .single();
    final id = row['id'].toString();
    if (code != null) return id;
    try {
      final minted = await mintCode(orgId);
      await SupabaseConfig.client
          .from('transactions')
          .update({'code': minted}).eq('id', id);
    } catch (_) {
      // kode nomor opsional — transaksi tetap tersimpan
    }
    return id;
  }
}
